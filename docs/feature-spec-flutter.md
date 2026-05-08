# Feature Spec — AI Form Builder (Flutter)

**Status:** Draft (Task 4 of Phase 2)
**Depends on:** `docs/api-contract.md`, `docs/rate-limiting-abuse.md`, `docs/ai-prompt-spec.md`, `SESSION_CONTEXT.md`
**Source of truth:** This document for all Flutter-side AI Form Builder behavior.

---

## 1. Screen Inventory & Navigation Graph

### 1.1 New screens

| Screen | Class | Route trigger | Notes |
|---|---|---|---|
| AI Form Builder Entry | `AiFormBuilderPage` | Dashboard button (§1.2) | Entry point; loads `/user/status` on mount |
| AI Form Preview | `AiFormPreviewPage` | Cubit emits `AiFormPreviewState` | Shown on successful generation |

No new routes are needed beyond these two. Paywall and editor use the **existing** `PaywallPage.show()` and editor push.

### 1.2 Navigation graph

```
DashboardPage
  │
  ├─[FAB long-press or "AI" icon button in app bar]
  │       │
  │       ▼
  │   AiFormBuilderPage
  │     │  (on mount: GET /user/status)
  │     │
  │     ├─[/user/status 401]──────────────────────► ErrorModal (token_expired) → pop
  │     │
  │     ├─[/user/status 200]
  │     │     │
  │     │     ├─[free, used < 3]  → AiFormBuilderReady (text only, counter visible)
  │     │     ├─[free, used = 3]  → AiFormBuilderReady (counter at 0, CTA to upgrade)
  │     │     ├─[premium]         → AiFormBuilderReady (full picker, premium counter)
  │     │     └─[/user/status unreachable — 503 / network]
  │     │              └──────────────────────────► ErrorModal (status_unavailable) → pop
  │     │
  │     ├─[User taps "Generate"]
  │     │     │
  │     │     ├─[free @ quota 0] → PaywallPage.show() (quota_counter_tap path)
  │     │     │
  │     │     └─[POST /ai/generate]
  │     │           │
  │     │           ├─[200 status=completed] ──────► AiFormPreviewPage
  │     │           │                                  │
  │     │           │                                  ├─[Tap "Create Form"]
  │     │           │                                  │       │
  │     │           │                                  │       └─[forms.create → setPublishSettings
  │     │           │                                  │          → batchUpdate → open EditorPage]
  │     │           │                                  │
  │     │           │                                  └─[Tap Back] ──► AiFormBuilderReady
  │     │           │                                                   (same idempotency key
  │     │           │                                                    retained; counter
  │     │           │                                                    already updated)
  │     │           │
  │     │           ├─[200 status=pending] ──────────► AiFormBuilderPolling (future; §2.5)
  │     │           │
  │     │           ├─[4xx / 429 / 503] ─────────────► ErrorModal or PaywallPage.show()
  │     │           │                                   (see §4)
  │     │           └─[network error / timeout client] → retry same key (§2.3)
  │     │
  │     └─[Back button at any point] ──────────────────► DashboardPage
  │                                                       (in-flight is fire-and-forget)
  │
  └─[PaywallPage.show() (various paths)]
        └─[Dismissed / subscribed] ──────────────────────► AiFormBuilderPage
                                                            (re-fetches /user/status)
```

### 1.3 First-run / never-generated states

| User | State | What they see |
|---|---|---|
| Free, 0 uses | `AiFormBuilderReady` | Quota counter "3 remaining". No reset date (null `freeResetsAt`). |
| Free, 1–2 uses | `AiFormBuilderReady` | Quota counter "2 remaining" / "1 remaining" + reset date sub-line. |
| Free, 3 uses | `AiFormBuilderReady` | Quota counter "0 remaining". Generate button disabled. Upgrade banner visible. |
| Premium, mid-period | `AiFormBuilderReady` | Quota counter "38/50 remaining" + renewal date. Full input picker shown. |
| `/user/status` unreachable | `ErrorModal` | "Couldn't load your quota. Check your connection and try again." + "Retry" CTA. Modal dismissal pops the screen. |

---

## 2. Cubit State Machine

### 2.1 Cubit and sealed states

```dart
// lib/features/ai_form_builder/presentation/cubit/ai_form_builder_cubit.dart
class AiFormBuilderCubit extends Cubit<AiFormBuilderState> { ... }

// lib/features/ai_form_builder/presentation/cubit/ai_form_builder_state.dart
sealed class AiFormBuilderState { ... }
```

| State | Fields | When emitted |
|---|---|---|
| `AiFormBuilderStatusLoading` | — | Immediately on cubit construction; `/user/status` call in flight |
| `AiFormBuilderReady` | `UserStatus status`, `String idempotencyKey`, `InputType selectedType`, `Duration elapsed` | `/user/status` 200; also returned to after modal dismissal |
| `AiFormBuilderSubmitting` | `UserStatus status`, `String idempotencyKey`, `InputType selectedType`, `Duration elapsed` | User taps Generate; request in flight |
| `AiFormBuilderPreview` | `UserStatus status`, `GeneratedForm form`, `String generationId`, `QuotaSnapshot quota` | `POST /ai/generate` 200 completed |
| `AiFormBuilderCreatingForm` | `GeneratedForm form` | User taps "Create Form" on preview |
| `AiFormBuilderEditorHandoff` | `String formId` | Forms API create + batchUpdate done; triggers pop + push to EditorPage |

Errors are never a state — they are transient modals emitted as side-effects via `ErrorModalEvent` or `PaywallEvent` (see §2.4). The cubit stays in or returns to the appropriate underlying state after the modal is dismissed.

### 2.2 Happy path transitions

```
AiFormBuilderStatusLoading
  → [/user/status 200]
  → AiFormBuilderReady (fresh idempotencyKey = UUIDv4())

AiFormBuilderReady
  → [user taps Generate (quota > 0)]
  → AiFormBuilderSubmitting (same idempotencyKey, elapsed = 0)

AiFormBuilderSubmitting
  → [200 status=completed]
  → AiFormBuilderPreview

AiFormBuilderPreview
  → [user taps "Create Form"]
  → AiFormBuilderCreatingForm

AiFormBuilderCreatingForm
  → [forms.create + batchUpdate success]
  → AiFormBuilderEditorHandoff(formId)
```

Back from Preview → `AiFormBuilderReady`. The idempotency key is **not** regenerated on back; if the user immediately retaps Generate with the same inputs the server returns a cached 200 at no extra quota cost.

### 2.3 Retry with same Idempotency-Key

On any retryable error (503 `gemini_unavailable`, `gemini_timeout`, `validation_error`, `service_busy`, `database_unavailable`, network timeout), the cubit:

1. Emits `ErrorModal` event with a "Try again" CTA.
2. On "Try again" tap: emits `AiFormBuilderSubmitting` with the **same `idempotencyKey`**.
3. The server deduplicates: if the first request silently completed (race between timeout and completion), the replay returns the cached 200. If not, a fresh Gemini call is made.

The idempotency key is only rotated when:
- A new `AiFormBuilderReady` is entered fresh (screen mount or post-paywall re-entry).
- The user edits the request body (changes prompt text or input type) — triggering "new logical attempt".

### 2.4 Error side-effects vs state

The cubit owns a `Stream<AiFormBuilderEvent>` (or uses `flutter_bloc`'s listener pattern) for side-effect events:

```dart
sealed class AiFormBuilderEvent {}
class ShowErrorModalEvent extends AiFormBuilderEvent {
  final ErrorModalConfig config;
}
class ShowPaywallEvent extends AiFormBuilderEvent {}
```

The presentation layer listens to these in `BlocListener` and calls `ErrorModal.show()` or `PaywallPage.show()`. This keeps the state clean and avoids snackbars (per §8.7 of SPEC.md).

### 2.5 Forward-compat for async (`status: "pending"`)

The cubit parses the `status` field on every 200 response **before** checking for `form`:

```dart
if (response.status == 'pending') {
  // TODO (future): emit AiFormBuilderPolling and start polling
  // For MVP: treat as gemini_unavailable (server should never return pending today)
  _emitError(ErrorCode.geminiUnavailable);
  return;
}
// status == 'completed'
emit(AiFormBuilderPreview(...));
```

No polling infrastructure is built now. The guard prevents a crash if the server ever returns `pending` in an unexpected scenario.

---

## 3. Free vs Premium UI

### 3.1 Input area

**Free tier** — input type selector is **hidden** (not rendered, not greyed, not locked):

```
┌─────────────────────────────────────────┐
│ Describe the form you want              │
│ ┌─────────────────────────────────────┐ │
│ │ e.g. "Customer feedback survey for  │ │
│ │ a small bakery"                     │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│ [Generate]                              │
└─────────────────────────────────────────┘
```

**Premium tier** — full input type picker shown above the text field:

```
┌─────────────────────────────────────────┐
│  [Text] [PDF] [YouTube] [URLs] [Book]   │  ← segmented picker
│                                         │
│  [input area changes per selection]     │
│                                         │
│ [Generate]                              │
└─────────────────────────────────────────┘
```

| Picker tab | Input shown | Hint copy |
|---|---|---|
| Text | Multi-line `TextField` (max 4000 chars) | "Describe the form you want" |
| PDF | "Upload PDF" file picker button; selected file name shown | "Up to 5 MB. Chapter PDFs work best." |
| YouTube | Single-line URL `TextField` | "Paste a YouTube URL" |
| URLs | Up to 5 URL fields, "+ Add URL" button | "Paste a website or blog link" |
| Book | "Upload PDF" file picker button + optional chapter title field | "Upload an extracted chapter (≤ 5 MB)" |

The client validates PDF size locally before encoding (`file.length > 5 * 1024 * 1024` → show inline "File too large" error, do not call server).

### 3.2 Quota counter

Shown below the page title on `AiFormBuilderPage`, always visible:

```
Free: "2 of 3 free generations remaining"
       sub-line: "Resets Jun 7" (shown if freeResetsAt != null)

Premium: "38 of 50 generations remaining"
          sub-line: "Renews Jun 1"
```

Counter is sourced from:
1. `GET /user/status` on entry.
2. The `quota` field in every successful `POST /ai/generate` 200 response — update counter immediately after generation without an extra round-trip.

When `used == limit` (free user):
- Counter text: "0 of 3 remaining"
- "Generate" button is **disabled**.
- Upgrade banner shown below counter: "Upgrade for 50 generations + PDF, YouTube & more → [Upgrade]".
  - Tapping the banner or counter chip → `PaywallPage.show()` (§6).

### 3.3 `/user/status` response → UI mapping

```dart
// isPremium drives which UI branch is shown
// Free path uses: aiFreeUsed, aiFreeLimit, freeResetsAt
// Premium path uses: aiPremiumUsed, aiPremiumLimit, premiumResetsAt
// gracePeriodUntil: shown as a banner ("Billing issue — service active until <date>")
//   but does not change any other UI. User still has full premium access.
```

---

## 4. Error → UI State Map

All errors are shown via `ErrorModal.show()` — no snackbars. The table below covers every `code` from `api-contract.md §6` plus the additional codes in `rate-limiting-abuse.md §4.6` and `§10.2`.

| HTTP | `code` | ErrorModal title | ErrorModal body | Primary CTA | Secondary CTA | Post-modal cubit state | Auto-retry? |
|---|---|---|---|---|---|---|---|
| 400 | `invalid_input` | "Invalid request" | "Something looks wrong with your input. Please check and try again." | "OK" | — | `AiFormBuilderReady` (same key) | No |
| 400 | `missing_idempotency_key` | "App error" | "An internal error occurred. Please try again." | "Try Again" | — | `AiFormBuilderReady` (new key) | No |
| 400 | `file_too_large` | "File too large" | "Your file is too large. Please use a file under 5 MB." | "OK" | — | `AiFormBuilderReady` (same key) | No |
| 400 | `unsupported_input_type` | "App error" | "An internal error occurred. Please try again." | "OK" | — | `AiFormBuilderReady` (new key) | No |
| 400 | `url_fetch_failed` | "Couldn't read URL" | "We couldn't access one of your links. Make sure it's publicly accessible and try again." | "OK" | — | `AiFormBuilderReady` (same key) | No |
| 400 | `youtube_unavailable` | "Video unavailable" | "This YouTube video is private, removed, or region-locked. Please try a different video." | "OK" | — | `AiFormBuilderReady` (same key) | No |
| 401 | `invalid_token` | "Session expired" | "Your session has expired. Please sign in again." | "Sign in" | — | pop screen, navigate to sign-in | No |
| 403 | `premium_required` | — | — | — | — | `PaywallPage.show()` (no modal; direct paywall) | No |
| 403 | `user_blocked` | "Account restricted" | "Your account has been restricted. Contact support if you think this is a mistake." | "OK" | "Contact Support" | `AiFormBuilderReady` | No |
| 409 | `idempotency_conflict` | "App error" | "An internal error occurred. Please try again." | "Try Again" | — | `AiFormBuilderReady` (new key generated) | No |
| 409 | `idempotency_in_flight` | "Already generating" | "Your last request is still in progress. Please wait a moment and try again." | "Try Again" (after 1s delay) | — | `AiFormBuilderReady` (same key) | Yes — 1s |
| 429 | `quota_exceeded` (free) | "No generations left" | "You've used all 3 free generations this month. Upgrade for 50 generations per month." + reset date | "Upgrade" | "Remind me later" | "Upgrade" → `PaywallPage.show()`; "Remind me later" → `AiFormBuilderReady` | No |
| 429 | `quota_exceeded` (premium) | "Monthly limit reached" | "You've used all 50 generations this month. Your limit resets on `<resetsAt>`." | "OK" | — | `AiFormBuilderReady` | No |
| 429 | `rate_limited` | "Slow down" | "You're generating forms too quickly. Try again in `<retryAfter>`." | "OK" | — | `AiFormBuilderReady` | No |
| 503 | `gemini_unavailable` | "AI service unavailable" | "The AI service is temporarily unavailable. Please try again in a moment." | "Try Again" | "Cancel" | "Try Again" → `AiFormBuilderSubmitting` (same key); "Cancel" → `AiFormBuilderReady` | No (manual) |
| 503 | `gemini_timeout` | "Taking too long" | "The AI is taking longer than expected. Your request may still be processing — tapping 'Try Again' will resume it if possible." | "Try Again" | "Cancel" | "Try Again" → `AiFormBuilderSubmitting` (same key); "Cancel" → `AiFormBuilderReady` | No (manual) |
| 503 | `validation_error` | "Generation failed" | "The AI produced an unexpected result. Please try again, or try rephrasing your input." | "Try Again" | "Cancel" | same as `gemini_unavailable` | No (manual) |
| 503 | `service_disabled` | "Feature unavailable" | "AI form generation is temporarily unavailable. Please try again later." | "OK" | — | `AiFormBuilderReady` | No |
| 503 | `service_busy` | "Service is busy" | "The service is unusually busy right now. Please try again in `<retryAfter>`." | "Try Again" | "Cancel" | same as `gemini_unavailable` | No (manual) |
| 503 | `daily_budget_exceeded` | "Service is unavailable" | "AI form generation is temporarily unavailable. Please try again tomorrow." | "OK" | — | `AiFormBuilderReady` | No |
| 503 | `database_unavailable` | "Service error" | "A temporary error occurred. Please try again." | "Try Again" | "Cancel" | same as `gemini_unavailable` | No (manual) |
| network | (no response) | "No connection" | "Check your internet connection and try again." | "Try Again" | "Cancel" | same key, `AiFormBuilderSubmitting` on retry | No (manual) |

**`quota_exceeded` routing detail:**
- The `details.tier` field in the 429 body determines which modal variant to show.
- Free users get the upgrade modal; premium users get the reset-date modal.
- Neither case shows `generationId` (per api-contract §4.1 — errors don't include it).

**Unknown error codes:** any unrecognized code at its HTTP status class gets the generic modal for that class:
- 4xx → "Request error. Please try again."
- 5xx → "A server error occurred. Please try again later."

---

## 5. Loading State Behavior

Loading state is shown while `AiFormBuilderSubmitting`. The spinner is embedded in the `AiFormBuilderPage` — **not** a full-screen overlay — so the back button remains accessible.

```
0s – 8s      ● Animated spinner + "Generating your form…"
8s – 20s     ● Spinner + "This is taking a moment…"
20s – 30s    ● Spinner + "Almost there…"
30s+         ● Server returns 503 gemini_timeout
             → ErrorModal: "Taking too long" (see §4)
             → User taps "Try Again" → AiFormBuilderSubmitting (same idempotencyKey)
             → Timer resets to 0s
```

Implementation: the cubit starts a `Timer.periodic(1s)` when entering `AiFormBuilderSubmitting`, updates `elapsed` in the state. The UI switches label text at 8s and 20s thresholds based on `state.elapsed`. The timer is cancelled when the cubit leaves `AiFormBuilderSubmitting`.

**Cancellation behavior:** tapping the back button while submitting pops the screen immediately. The in-flight request is **fire-and-forget** — the server continues executing and caches the result (if successful) against the idempotency key. If the user re-enters the page and submits the same prompt with the same key (retained by the cubit if they don't dismiss it), the server returns a cached 200 instantly.

---

## 6. Paywall Trigger Paths

All paths call the existing **`PaywallPage.show(context)`** — no new paywall implementation needed.

| Trigger path | Where | Condition |
|---|---|---|
| Quota counter tap at zero remaining | `AiFormBuilderPage` quota chip | Free user, `aiFreeUsed == aiFreeLimit` |
| "Upgrade" CTA in the upgrade banner | `AiFormBuilderPage` (free user at quota) | Same |
| "Upgrade" button in `quota_exceeded` modal | `ErrorModal` primary CTA | 429 `quota_exceeded` with `details.tier == "free"` |
| Defensive 403 `premium_required` | `AiFormBuilderSubmitting` error handler | Free user selected premium input type (shouldn't happen if UI hides picker, but server is the source of truth) |

After `PaywallPage` is dismissed (subscription purchased or cancelled), the cubit calls `GET /user/status` again to refresh quota and tier. This handles the case where a user subscribed mid-session.

**Non-AI paywall paths** (CSV export, etc.) are out of scope for this screen.

---

## 7. Integration with Existing App

### 7.1 Feature directory

Directory name **must be confirmed with the user before any code is written**. Suggested: `lib/features/ai_form_builder/` (sibling to `lib/features/dashboard/` and `lib/features/editor/`). Do not hardcode a different name.

### 7.2 Clean architecture layers

Mirroring the existing `dashboard` and `editor` features:

```
lib/features/ai_form_builder/
  domain/
    entities/
      generated_form.dart          // maps to api-contract §3 Form + Question
      user_status.dart             // maps to api-contract §3 UserStatusResponse
      quota_snapshot.dart          // maps to api-contract §3 QuotaSnapshot
    repositories/
      ai_form_repository.dart      // abstract
    usecases/
      get_user_status.dart
      generate_form.dart
      create_form_from_ai.dart     // calls existing forms.create + batchUpdate
  data/
    datasources/
      ai_form_datasource.dart      // HTTP to middleware; Google ID token auth
    repositories/
      ai_form_repository_impl.dart
  presentation/
    cubit/
      ai_form_builder_cubit.dart
      ai_form_builder_state.dart
    pages/
      ai_form_builder_page.dart
      ai_form_preview_page.dart
```

**State management:** `flutter_bloc` Cubits — not Riverpod. Consistent with the rest of the app.

**DI:** register in `lib/core/di/injection.dart` alongside the existing `DashboardCubit` and `EditorCubit` registrations.

**The Flutter app never calls Gemini directly.** All AI goes through the middleware via `AiFormDataSource`.

### 7.3 Authentication

`AiFormDataSource` sends the Google ID token via:

```dart
final idToken = await googleSignIn.currentUser?.authentication
    .then((auth) => auth.idToken);
// Header: Authorization: Bearer $idToken
```

Reuses the existing `_GoogleAuthClient` pattern from `lib/core/auth/google_auth_datasource.dart`.

### 7.4 On-success flow: AI JSON → real Google Form

After `AiFormBuilderPreview` → user taps "Create Form" → `AiFormBuilderCreatingForm`:

1. **`forms.create`** — create a blank form with the AI-generated title and description (same pattern as `DashboardDataSource.createForm`; do NOT pass items).
2. **`setPublishSettings`** — forms are unpublished by default since March 31 2026; must call this after create.
3. **`batchUpdate`** — one `createItem` request per question in the AI JSON, in order.
4. Navigate to `EditorPage` with the new `formId`.

The `create_form_from_ai.dart` use case encapsulates steps 1–3, delegating the HTTP calls to the **existing** `EditorDataSource` methods (`createForm`, `batchUpdate`).

### 7.5 AI-enum → Forms API item shape mapping

The 9 supported AI question types map to `batchUpdate` `createItem` request bodies as follows. `FileUploadQuestion` is not in the AI schema and is not created.

| AI `type` | Forms API item shape in `createItem` |
|---|---|
| `SHORT_ANSWER` | `questionItem: { question: { textQuestion: { paragraph: false }, required: <bool> }, title: <str>, description: <str?> }` |
| `PARAGRAPH` | `questionItem: { question: { textQuestion: { paragraph: true }, required: <bool> }, title: <str>, description: <str?> }` |
| `MULTIPLE_CHOICE` | `questionItem: { question: { choiceQuestion: { type: "RADIO", options: [ { value: <str> }, ... ] }, required: <bool> }, title: <str>, description: <str?> }` |
| `CHECKBOXES` | `questionItem: { question: { choiceQuestion: { type: "CHECKBOX", options: [ { value: <str> }, ... ] }, required: <bool> }, title: <str>, description: <str?> }` |
| `DROPDOWN` | `questionItem: { question: { choiceQuestion: { type: "DROP_DOWN", options: [ { value: <str> }, ... ] }, required: <bool> }, title: <str>, description: <str?> }` |
| `LINEAR_SCALE` | `questionItem: { question: { scaleQuestion: { low: <scaleMin>, high: <scaleMax>, lowLabel: <scaleMinLabel?>, highLabel: <scaleMaxLabel?> }, required: <bool> }, title: <str>, description: <str?> }` |
| `DATE` | `questionItem: { question: { dateQuestion: { includeTime: false, includeYear: true }, required: <bool> }, title: <str>, description: <str?> }` |
| `TIME` | `questionItem: { question: { timeQuestion: { duration: false }, required: <bool> }, title: <str>, description: <str?> }` |
| `RATING` | `questionItem: { question: { ratingQuestion: { ratingScaleLevel: <ratingScale>, iconType: "STAR" }, required: <bool> }, title: <str>, description: <str?> }` |

`description` is omitted (not null) when the AI returns it as empty string or null, consistent with the existing `_toApiItemForCreate` pattern that uses `removeNulls`. `title` is always present (guaranteed by the AI schema).

RATING `iconType: "STAR"` is the only icon supported without additional configuration; use it unconditionally.

---

## 8. Task 4 Acceptance Checklist

Review before signing off:

- [x] **Free vs premium UI explicitly differentiated (input type selector hidden for free)**
  → §3.1: selector is hidden (not rendered) for free users. Premium shows the full segmented picker.

- [x] **Quota counter visible on entry ("2/3 remaining")**
  → §3.2: counter shown on `AiFormBuilderPage`, sourced from `/user/status` on mount and refreshed from `quota` field on every successful `/ai/generate` 200.

- [x] **Every API error from Task 1 has a matching UI state**
  → §4: table covers all 20+ `code` values from `api-contract.md §6` plus `service_busy`, `service_disabled`, `daily_budget_exceeded`, `user_blocked` from `rate-limiting-abuse.md §4.6` and `§10.2`. Unknown codes have a generic fallback.

- [x] **Paywall trigger paths enumerated (quota exhausted, premium-only input type)**
  → §6: four trigger paths documented — quota counter tap, upgrade banner CTA, `quota_exceeded` modal upgrade button, and defensive 403 `premium_required` handling.

- [x] **Loading state handles 30s Gemini timeout**
  → §5: three-phase label progression (0–8s / 8–20s / 20–30s), server returns 503 `gemini_timeout` at 30s, retry with same `Idempotency-Key`.
