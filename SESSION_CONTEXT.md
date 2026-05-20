# Session Context — Mobile Google Forms Companion

Read this file at the start of every session before touching any code.

---

## Build progress

| Step | Status | Notes |
|------|--------|-------|
| 1 Auth + API clients | ✅ Done | `google_sign_in` + `_GoogleAuthClient`, `FormsClient`, `DriveClient`, `get_it` DI |
| 2 Dashboard read path | ✅ Done | Drive `files.list`, tap → `forms.get`, full list UI |
| 3 Domain models | ✅ Done | Manual sealed classes, freezed for ChoiceOption; all round-trip tests pass |
| 4 Create form + publish | ✅ Done | `forms.create` → default question → `setPublishSettings` |
| 5 Editor read-only | ✅ Done | All item types rendered |
| 6 Editor write — title/desc | ✅ Done | 600ms debounce, `updateFormInfo`, revision mismatch retry, conflict modal |
| 7 Add/delete/reorder | ✅ Done | `createItem` / `deleteItem` / `moveItem`, optimistic UI |
| 8 Edit question content | ✅ Done | title, options, required toggle all wired |
| 9 All question types | ✅ Done | Type picker sheet, 10 types, `_mergeOptions` guarantees options |
| 10 Sections + branching | ✅ Done | `pageBreakItem`, `goToSectionId` on RADIO/DROP_DOWN options |
| 11 Deferred Save | ✅ Done | Save button, local pending changes, flush on press |
| 12 Form settings sheet | ✅ Done | `updateSettings` (quiz mode + email collection), inline settings tab |
| 13 Preview + Share | ✅ Done | Full-screen webview (`PreviewScreen`), `Share.share` |
| 14 Responses list + detail | ✅ Done | `ResponsesScreen` + `ResponseDetailScreen`, paginated load, sorted newest-first |
| 15 Quiz mode | ✅ Done | Per-question grading editor |
| 16 Editor UI overhaul | ✅ Done | New AppBar, action strip, tab bar, redesigned cards, bottom bar |
| Clean arch — Dashboard | ✅ Done | domain/data/presentation layers |
| Clean arch — Editor | ✅ Done | domain/data/presentation layers; retry engine in repo impl |
| Responses tab redesign | ✅ Done | Summary + Individual sub-tabs; choice bars, text previews, numeric averages |
| Paywall page | ✅ Done | `PaywallPage.show()`, plan selector (Weekly/Annual/Monthly), crown icon nav from dashboard + editor |
| CSV export | ✅ Done | Settings tab → loads all responses → builds CSV → `Share.shareXFiles`; no paywall gate for now |
| Linked sheet button | ✅ Done | Settings tab → `url_launcher` opens sheet in browser when `linkedSheetId` present |
| YouTube video insert | ✅ Done | Search dialog → `addVideoItem` → `VideoItemContent` → Forms API |
| Image insert | ✅ Done | URL paste or gallery picker → Drive upload → public URL → `ImageItemContent` |
| Polish — empty states | ✅ Done | All screens have icon + text empty states (dashboard, editor, responses) |
| RevenueCat integration | ✅ Done | `purchases_flutter` wired, real products, CSV export gated behind `gfm_premium` entitlement, paywall UI polish |
| **Phase 2 — AI Form Builder (planning)** | 🔄 In progress | Spec doc in `Tasks.md` — 7 tasks. **All 7 spec tasks ✅ Done** → `docs/api-contract.md`, `docs/db/migrations/001_init.sql` + `docs/db/scripts/cleanup_expired_generations.sql`, `docs/ai-prompt-spec.md`, `docs/feature-spec-flutter.md`, `docs/revenuecat-webhook-map.md`, `docs/rate-limiting-abuse.md`, `docs/observability.md`. **Implementation not started — ready to begin.** |
| 17 Duplicate form/question | ⬜ Out of scope for MVP | |
| 18 Offline queue | ⬜ Out of scope for MVP | |
| 19 IAP / paywall wiring | ⬜ Out of scope for MVP | |
| Analytics + Crashlytics | ✅ Done | Firebase Analytics + Crashlytics; DebugView confirmed working |
| Template gallery | ✅ Done | 17 templates across Work/Personal/Education; data matches exact Google Forms content verified by screenshots; `FormTemplate.quizMode` field added; Blank Quiz creates with quiz mode enabled via `enableQuizMode()` in `FormsDataSource`; Blank Quiz moved to top beside Blank Form; all 4 Education thumbnails added; full UI redesign (2-column grid, bordered sections, lavender blank cards, Lato font) |
| Side drawer / nav menu | ✅ Done | Purple header, 5 sections (Subscription, Support Us, Feedback, Policy, Sign Out), white rounded cards per section, custom PNG asset icons, chevrons; `assets/` declared as directory in pubspec |
| Production readiness | 🔄 In progress | OAuth verification ✅, app signing, store submission |

---

## Critical architecture decisions

### State management
- `flutter_bloc` Cubits (NOT Riverpod — CLAUDE.md says Riverpod but codebase uses Bloc; do not change)
- `EditorCubit` holds `form` + `lastKnownGood` for rollback, `isSaving`, `conflictPending`
- `PendingChanges` tracks titleDesc, creates, deletes, edits locally — flushed on Save

### API write pattern
Every form mutation goes through `EditorRepositoryImpl.batchUpdate`:
1. First attempt with `WriteControl.requiredRevisionId`
2. On revision mismatch (400): fetch fresh revision, retry once
3. Second mismatch: returns `Left(RevisionMismatchFailure())` → cubit emits `conflictPending: true`
4. Non-revision 400: returns `Left(ServerFailure())` immediately (no retry)
5. Network/5xx: backoff 1s → 3s → 8s in repo impl

`EditorCubit._sendBatch` folds the Either — throws `Failure` on Left so `save()` catch block handles rollback.

### Serialization quirk — IMPORTANT
`googleapis` `Form.toJson()` puts nested Dart objects directly in the map (not plain Maps).
Fix: always `jsonDecode(jsonEncode(apiForm.toJson()))` before passing to `FormDoc.fromJson()`.
Used in: `EditorDataSource.getForm`.

### Domain models
Manual sealed classes (not freezed) for `QuestionKind` and `ItemContent` because the Forms API
uses key-presence dispatch (e.g. `json.containsKey('textQuestion')`), not a type discriminator.
`ChoiceOption` uses freezed. `FormDoc`, `Item`, `Question` are manual with `fromJson`/`toJson`/`copyWith`.

### Image insert — Drive upload flow
`image_picker` → bytes → `DriveClient.uploadImage()` → Drive multipart upload → set `anyone/reader` permission → `https://drive.google.com/uc?id={fileId}&export=view` → used as `sourceUri` in `ImageItemContent`.
Scope: `drive.file` (already in use). No new scope needed.

### File upload questions
`FileUploadQuestion` exists in the domain model as read-only. The Forms API does **not** support creating file upload questions — they can only be created via the web UI. Do not attempt to add this.

---

## Key files

```
lib/
  core/
    api/
      concurrency.dart            runBatchUpdate() + isRevisionMismatch()
      forms_client.dart           FormsApi wrapper
      drive_client.dart           DriveApi wrapper + uploadImage()
    auth/
      google_auth_datasource.dart GoogleSignIn + _GoogleAuthClient + OAuth header injection
    di/injection.dart             get_it registrations (all features)
    error/failure.dart            sealed Failure hierarchy (Network/Auth/Server/NotFound/Permission/RevisionMismatch)
    usecases/usecase.dart         UseCase<T,P> base + NoParams
    models/
      form_doc.dart               Top-level form model
      item.dart                   Item with ItemContent sealed union
      item_content.dart           6 variants: QuestionItem, QuestionGroup, PageBreak, Text, Image, Video
      question.dart               Question with QuestionKind sealed union
      question_kind.dart          8 variants: Text, Choice, Scale, Date, Time, Rating, Row, FileUpload
      choice_option.dart          freezed, handles goToAction branching
      enums.dart                  ChoiceType, RatingIconType, GoToAction, EmailCollectionType
      form_response.dart          FormResponse — responseId, createTime, respondentEmail, answers map
  features/
    sign_in/
      domain/{entities,repositories,usecases}/
      data/repositories/auth_repository_impl.dart
      presentation/cubit/sign_in_cubit.dart
      presentation/screens/sign_in_screen.dart
    dashboard/
      domain/entities/form_entry.dart
      domain/repositories/form_repository.dart
      domain/usecases/{get_forms,create_form,delete_form}.dart
      data/datasources/{drive,forms}_datasource.dart
      data/repositories/form_repository_impl.dart
      presentation/cubit/dashboard_cubit.dart
      presentation/pages/dashboard_page.dart
    editor/
      domain/repositories/editor_repository.dart    abstract EditorRepository + BatchUpdateResult
      domain/usecases/load_form.dart                UseCase<FormDoc, String>
      domain/usecases/execute_batch.dart            UseCase<BatchUpdateResult, ExecuteBatchParams>
      domain/usecases/refresh_revision.dart         UseCase<String, String>
      domain/usecases/update_editor_settings.dart   UseCase<void, UpdateSettingsParams>
      data/datasources/editor_datasource.dart       raw API calls, removeNulls helper
      data/repositories/editor_repository_impl.dart Either-wrapped + full retry engine
      presentation/cubit/editor_cubit.dart          local state, flush ordering, _sendBatch thin wrapper
      presentation/cubit/editor_state.dart          EditorLoading/Loaded/Error + PendingChanges
      presentation/pages/editor_page.dart           BlocProvider + _EditorView (TabController, auto-scroll on add)
      presentation/widgets/
        form_header_card.dart       Editable title + description
        question_card.dart          Purple left border, type chip, options preview, edit/delete buttons
        question_edit_sheet.dart    Full question edit bottom sheet
        type_chip.dart              Color-coded pill, showCaret flag
        type_picker_sheet.dart      Bottom sheet, 10 types grouped free/advanced
        section_card.dart           SectionCard + TextBlockCard + TextBlockEditSheet
        image_url_dialog.dart       URL paste + gallery picker + Drive upload flow
        video_search_dialog.dart    YouTube search + insert
        settings_sheet.dart         (legacy — not actively used; settings are inline in editor tab)
    responses/
      presentation/pages/responses_page.dart  ResponsesScreen + ResponseDetailScreen; Summary + Individual tabs
    preview/
      preview_screen.dart         Full-screen WebViewWidget loading responderUri
```

---

## Bugs fixed (do not reintroduce)

1. **`addQuestion` refresh**: was calling `loadForm` (emits `EditorLoading` → destroys whole tree). Fix: `_silentRefresh` fetches form in-place without loading state.
2. **Reorder index bug**: header was at index 0 in `ReorderableListView`, offsetting all item indices. Fix: header in `SliverToBoxAdapter`, items in `SliverReorderableList` with clean 0-based indices.
3. **Save-status rebuilds**: every `saveStatus` change rebuilt entire Scaffold. Fix: `BlocSelector` for app bar, `buildWhen` guards on body.
4. **ChoiceQuestion empty options**: type switch from non-choice type sent `options: []` → API 400. Fix: `_mergeOptions` always seeds at least `[ChoiceOption(value: 'Option 1')]`.
5. **`FormsResourceApi`**: wrong class name in `concurrency.dart`. Correct: `FormsResource`.
6. **`explicit_to_json`**: nested freezed objects weren't calling `.toJson()`. Fix: `build.yaml` sets `explicit_to_json: true`.
7. **`googleapis` version**: `setPublishSettings` not in v13. Fixed: upgraded to `^16.0.0`.
8. **`_toApiItem` crash** (`type 'Null' is not a subtype...`): freezed `toJson()` includes null fields; `googleapis` `fromJson` crashes. Fix: `removeNulls` helper strips null keys recursively before `forms_api.Item.fromJson`.
9. **Scroll triggers reorder**: `ReorderableDragStartListener` started drag on any touch. Fix: switched to `ReorderableDelayedDragStartListener`.
10. **FocusNode double dispose**: `_QuestionCardState.dispose()` called dispose on a node owned by `_TitleFieldState`. Fix: removed dispose call from card state.
11. **`createItem` temp IDs**: Forms API rejects output-only `itemId`/`questionId`. Fix: `_toApiItemForCreate` strips both before the API call.
12. **`updateItem` temp IDs**: editing a newly created item before saving sent a temp `itemId`. Fix: substitute real server ID from `tempIdMap`.
13. **400 errors retried for 12s**: non-revision 400 (bad request) hit the full backoff loop. Fix: throw immediately on non-revision 400.
14. **Pure reorder not dirty**: `isDirty` only checked `pending`. Fix: `EditorLoaded.isDirty` also compares current item order vs `serverItemOrder`.
15. **`ChoiceOption.value` null crash**: Google Forms API returns `null` for `value` on some options (e.g. "Other"). Fix: `json['value'] as String? ?? ''` in `choice_option.g.dart`.
16. **`EditorCubit` emit-after-close**: cubit closed before async `loadForm`/`updateSettings`/`save` completed → "Bad state: Cannot emit new states after calling close". Fix: `if (isClosed) return` guards after each `await` before emit.
17. **Template items not created for grid templates**: `_stripIds` only removed `questionId` from `questionItem.question`, not from `questionGroupItem.questions` rows. The Forms API rejected the whole batch; the `catch (_) {}` silently swallowed it. Fix: strip `questionId` from all rows in `questionGroupItem.questions`; add logging to the catch block.
18. **RevenueCat `app_user_id` was email, webhook expected `google_sub`**: every paid subscription silently failed — `findByGoogleSub(email)` returned null, webhook hit the `rc_webhook_unknown_user` branch and ack'd 200 without crediting quota or flipping `is_premium`. Fix: added `googleId` to `AuthUser` (from `GoogleSignInAccount.id`), passed it to `Purchases.logIn`. Webhook lookup now resolves correctly. Do NOT change `Purchases.logIn` to use email or any other identifier — must remain the Google ID-token `sub`.
19. **`DashboardCubit` emit-after-close on import**: same pattern as #16 but for the dashboard's `importForm`. The cubit was being closed mid-flight while the WebView import flow was pushed, and the post-pop `emit` threw `Bad state: Cannot emit new states after calling close`. Fix: `if (isClosed) return` guards in `DashboardCubit.importForm`.
20. **Stale grading on non-quiz forms**: `QuestionEditSheet._commit` seeded `grading` from the question's existing value. If the form had been switched out of quiz mode, that stale grading tagged along on every save → API 400 `Invalid grading, grading cannot be set on a form that has no grading settings`. Fix: start `grading` as null, only build it when `widget.isQuiz` is true.
21. **`CorrectAnswer.value` null crash on import**: imported forms with quiz data crashed in `_$$CorrectAnswerImplFromJson` because Google Forms returns `null` for `value` on some `CorrectAnswer` entries (same family as #15). Fix: `json['value'] as String? ?? ''` in `grading.g.dart`.

## What NOT to do

- Do NOT add snackbars/toasts — spec §8.7 bans them. Use `ErrorModal.show()` only.
- Do NOT call `loadForm` during editing — causes full widget tree destruction.
- Do NOT use `forms.create` with items — API rejects everything except `info`.
- Do NOT hand-roll REST calls — use `package:googleapis` only.
- Do NOT skip `setPublishSettings` after create — forms are unpublished by default since March 31 2026.
- Do NOT use `identical()` for `FormDoc` equality check on item changes — `copyWith` always creates a new list reference.
- Do NOT pass null-containing maps to `googleapis` `fromJson` — always run `removeNulls` first (freezed includes null fields in `toJson`).
- Do NOT attempt to create `FileUploadQuestion` via the API — it is read-only.

---

## Deferred Save design

**All changes are tracked locally in `PendingChanges`, flushed on Save press.**

| Change type | Local tracking |
|---|---|
| Title / description | Latest value only (last write wins) |
| Add item | Ordered list of `PendingCreate` (with temp IDs) |
| Delete item | Set of real item IDs |
| Edit item content | Set of item IDs with mutated content (last write wins per item) |
| Reorder | NOT queued — derived at flush time from final local order vs `serverItemOrder` |

### Flush order on Save
1. Title/desc update (`updateFormInfo`)
2. Creates — sequential, capture real server ID from each response
3. Refresh revision + `serverItemOrder` mid-save
4. Deletes — batch in descending index order (avoids index shift)
5. Edits — batch all in one call (with real IDs substituted for temp IDs)
6. Moves — computed by diffing final local item order against simulated server order
7. `_silentRefresh` — replaces local FormDoc with clean server state

---

## Auth scopes (current)

```
drive.file
forms.body
forms.responses.readonly
```

`drive.file` covers both reading/listing Drive files created by the app and the image upload flow.
No Sheets API scope — export is CSV-only (via share_plus), linked sheet opened in browser.

---

## Recent changes (2026-05-10 session)

### AI Form Builder — fixes and features shipped

**Model switch**
- Changed Gemini model to `gemini-2.5-flash-lite` in `gfm_mw/src/infrastructure/gemini/gemini-client.ts`
- Updated pricing in `pg-ai-generation.repository.ts`: `$0.10/M` input, `$0.40/M` output

**Book type 400 fix**
- `BookRequest` schema had `.strict()` but was missing `fileName` (Flutter sends it) → added `fileName: z.string().max(255).optional()` to `BookRequest` in `request-schema.ts`

**Book timeout fix**
- `DEFAULT_DEADLINE_MS = 60_000` was too short for large PDFs/books → added `FILE_DEADLINE_MS = 120_000` applied for `pdf`/`book` input types in `generator.ts`; YouTube stays at 180s

**PDF/book multi-quota system**
- New file `gfm_mw/src/ai/pdf-pages.ts`: `countPdfPages(base64)` using `pdf-lib`, `pdfQuotaCost(pages, pagesPerQuota)`
- Config key `PDF_PAGES_PER_QUOTA` (default 50) added to `env.ts` and `config-service.ts`
- New endpoint `POST /ai/pdf-page-count` — returns `{ pages, quotaCost, pagesPerQuota }` (auth required, pre-flight)
- Generate handler: `quotaCost = ceil(pages / PDF_PAGES_PER_QUOTA)`; quota gate checks `used + quotaCost > limit`
- `incrementFreeUsed` / `incrementPremiumUsed` now accept `by` parameter; `runGeneration` passes `quotaCost`
- New admin page `DocumentsPage.tsx` with pages-per-quota setting and cost reference table
- `confirmedQuotaCost` pattern: client sends confirmed cost from pre-flight; server returns 409 `quota_cost_changed` if mismatch (prevents silent over-charging)

**Book prompt fix**
- Strengthened `bookTurn` and `pdfTurn` prompts in `build-contents.ts` to explicitly require questions from the SPECIFIC document content, not generic questions

**Question count picker**
- Flutter: replaced chip-based question count selector with `_QuestionCountPicker` StatefulWidget — editable TextField + `_CounterButton` (−/+), range 3–50
- Backend receives `questionCountHint` and passes it into the Gemini prompt

**Budget cap system removed** (user decision: cap from Google AI Studio instead)
- Removed 6 env vars: `MAX_DAILY/WEEKLY/MONTHLY_GEMINI_SPEND_USD`, `MAX_USER_DAILY/WEEKLY/MONTHLY_GEMINI_USD`
- Removed `perUserBudgetMiddleware`, `globalBudgetMiddleware` from kill-switch middleware
- Removed `getTotalSpendUsd`, `getGlobalSpendUsd` from repository interface + implementation
- Removed `GET /admin/spend` endpoint, `geminiSpendUsd`, `geminiSpendCapUsd`, `costBreakerTrippedTotal` metrics
- Deleted `BudgetCapsPage.tsx`, removed Budget Caps nav item and route from `admin/src/App.tsx`
- Simplified `/health` response (no spend window data)

---

## Recent changes (2026-05-11 session)

### AI Form Builder — quiz generation (end-to-end)

**Unified prompt** (form + quiz auto-detection)
- Bumped `PROMPT_VERSION` to `v3` in `gfm_mw/src/ai/system-prompt.ts`
- Model decides `isQuiz` from user input (keywords + intent); no UI toggle required
- Critical "never include X in Y mode" rules to prevent field leakage between modes
- Quiz fallback uses `isQuiz: false` (schema-valid)
- Prompt-injection rule extended to file content (PDF/YouTube/URL/book)

**Schema layer** (gfm_mw/src/ai/)
- `simple-schema.ts`: added `isQuiz`, `correctAnswers`, `pointValue`, `whenRight`, `whenWrong` to `SimpleQuestion` + `SIMPLE_RESPONSE_SCHEMA`. `superRefine` enforces: gradeable types only for quiz, correctAnswers required, options-must-match-correctAnswers, no quiz fields on form questions
- `form-schema.ts`: nested `Grading` object on gradeable types only (MULTIPLE_CHOICE / CHECKBOXES / DROPDOWN / SHORT_ANSWER); cross-field validation in `FormSchema.superRefine`
- `normalizer.ts`: folds quiz fields into nested `grading` object on gradeable questions
- `few-shots.ts`: bakery shot updated with `isQuiz: false`; quiz shot rebuilt with full grading fields (correctAnswers, pointValue, whenRight, whenWrong)

**Flutter layer** (lib/features/ai_form_builder/)
- `domain/entities/generated_form.dart`: new `AiGrading` class; `isQuiz` on `GeneratedForm`; `grading` on `AiQuestion`
- `data/repositories/ai_form_repository_impl.dart`: `_buildGrading` helper attaches Forms API `Grading` to choice/short questions; `enableQuizMode(formId)` called after batchUpdate when `isQuiz: true`
- SHORT_ANSWER feedback routed to `generalFeedback`; choice types use `whenRight`/`whenWrong` (per Forms API constraint)

---

## Recent changes (2026-05-11 session — quota system redesign)

### Quota System — Tasks Q1–Q7 complete

**DB migration** (`gfm_mw/migrations/004_quota_system.sql`, also at `docs/db/migrations/004_quota_system.sql`)
- Dropped old tier counters (`ai_free_used`, `ai_premium_used`, `free_month_reset_at`, `premium_reset_at`) from `users`
- Added `quota_balance`, `free_quota_reset_at`, `subscription_product_id` to `users`
- New tables: `quota_products` (seeded with 7 products), `quota_transactions` (audit log), `quota_whitelist`
- Developer email seeded into `quota_whitelist`; existing users seeded with free monthly balance
- Migration registered as `004` in `migrate.ts`

**Backend domain layer**
- New entities: `quota-product.ts`, `quota-whitelist-entry.ts`
- New repository interfaces: `quota-product.repository.ts`, `quota-whitelist.repository.ts`
- New implementations: `pg-quota-product.repository.ts`, `pg-quota-whitelist.repository.ts`
- `user.entity.ts`: replaced tier counters with `quotaBalance`, `freeQuotaResetAt`, `subscriptionProductId`
- `user.repository.ts`: removed `incrementFreeUsed`/`incrementPremiumUsed`/`resetFreeQuotaIfExpired`; added `creditQuota`, `debitQuota`, `applyFreeGrantIfDue`, `getQuotaBalance`, `setSubscriptionProduct`
- `pg-user.repository.ts`: CTE-based atomic debit/credit queries; conditional UPDATE for double-credit prevention
- `auth.middleware.ts` + `express/index.d.ts`: added `email` to `req.user`

**Backend routes**
- `ai.routes.ts`: whitelist short-circuit (skip grant + gate + debit), `applyFreeGrantIfDue` before quota gate, balance-based gate, debit after success; `QuotaSnapshot` shape → `{balance, quotaCost, unlimited}`
- `user.routes.ts`: removed tier constants; returns `quotaBalance` + `unlimited`
- `webhook.routes.ts`: `INITIAL_PURCHASE`/`RENEWAL` → `creditQuota` + `setSubscriptionProduct`; `NON_RENEWING_PURCHASE` (new top-up handler); `EXPIRATION`/`REFUND` → `setSubscriptionProduct(null)`; `PRODUCT_CHANGE` → updates subscription product
- `admin.routes.ts`: `GET/PATCH /admin/quota-products`, `GET/POST/DELETE /admin/whitelist`
- `generator.ts`: removed debit calls from `finalize()` (debit moved to route handler)

**Admin UI**
- New pages: `QuotaProductsPage.tsx` (inline editable quota amounts, type badges), `WhitelistPage.tsx` (add/remove entries)
- `App.tsx`: added Quota Products + Whitelist nav items and routes
- `api.ts`: added typed API helpers for quota products and whitelist
- `vite.config.ts`: added `/admin/quota-products` and `/admin/whitelist` to Vite proxy

**Flutter**
- `quota_snapshot.dart`: `{balance, quotaCost, unlimited}` replaces `{tier, used, limit, resetsAt}`; `QuotaTier` enum removed
- `user_status.dart`: `{quotaBalance, unlimited}` replaces all tier counters; `isQuotaExhausted` uses balance model
- `failure.dart`: `QuotaExceededFailure` fields → `balance`, `quotaCost` (was `used`, `limit`, `resetsAt`)
- `ai_form_datasource.dart`: parses new 429 response shape
- `ai_form_builder_cubit.dart`: `_applyQuota` simplified to balance model; paywall check uses `unlimited`
- `ai_form_builder_page.dart`: `_QuotaCounter` renders "Unlimited" or "$balance generations remaining"; PDF confirm dialog updated

---

---

## Recent changes (2026-05-13 session)

### Paywall page — iOS redesign

- Full redesign to match dashboard/AI builder iOS style: `Color(0xFFF2F2F7)` gray background, `AppBar` with `elevation: 0` / `surfaceTintColor: Colors.transparent`, centered "GFM Premium" title, purple `arrow_back_ios_new` leading button
- Restored original 3-card plan selector (`_FeaturedPlanCard` / `_SidePlanCard`) — horizontal Weekly / Annual (featured, "Save 78%" badge) / Monthly layout
- "What's Included" section: minimal checklist (purple circle + check icon + label), wrapped in white rounded card
- First checklist item is dynamic — updates when user taps a plan: "15 AI generations per week" / "50 AI generations per month" / "700 AI generations per year"

### RevenueCat product ID alignment

- Updated `_offeringId` in `subscription_service.dart` from `'gfmDefault'` → `'GFMDefault'`
- Migration `005_rename_subscription_products.sql`: inserts new `quota_products` rows (`GFM_Weekly_3.99`, `GFM_Monthly_4.99`, `GFM_Yearly_44.99`), re-points `quota_transactions` and `users.subscription_product_id`, deletes old rows (`gfm_weekly`, `gfm_monthly`, `gfm_yearly`). Registered as `id: "005", seededTable: "_never"` in `migrate.ts`

### Security fixes

- **Removed `kBypassPremium`** from `subscription_service.dart` — was a hardcoded bypass that would give all users free premium if shipped as `true`. Whitelist in DB covers testing needs safely.
- **Editor CSV export premium gate** — replaced `SubscriptionService.isPremium()` (RevenueCat client-side) with `GetUserStatus` (server `/user/status` endpoint), consistent with AI builder. Server is source of truth; whitelist and quota state are now respected.

### Payment/subscription audit — fixes (commit `eca733e`)

**P0 — RevenueCat identity bug**
- Flutter was calling `Purchases.logIn(user.email)`, but the webhook resolves users via `findByGoogleSub(event.app_user_id)`. Email ≠ google_sub, so every paid subscription silently landed in `rc_webhook_unknown_user` — no quota credited, `is_premium` never flipped.
- Fix: added `googleId` to `AuthUser`, populated from `GoogleSignInAccount.id` (= ID-token `sub`) in `auth_repository_impl.dart`, and `SignInCubit` now passes `user.googleId` to `_subscriptionService.identifyUser(...)`.

**App Store paywall requirements** (guideline 3.1.2)
- `paywall_page.dart` footer rebuilt: auto-renewal disclosure paragraph + 4-link wrap row — Restore Purchases · Manage Subscription · Privacy Policy · Terms of Use.
- Manage Subscription deep-links to `https://apps.apple.com/account/subscriptions`. Privacy/Terms reuse the URLs from the sign-in screen.

**Sandbox webhook passthrough for App Store reviewers**
- `webhook.routes.ts` reordered to resolve user before the sandbox gate. In production, sandbox events are still skipped for unknown users, but now **processed normally for any user whose email is in `quota_whitelist`**.
- Submission workflow: create a dedicated reviewer Google account → add its email to `quota_whitelist` via admin → list it as the demo account in App Store Connect. Reviewer's sandbox StoreKit purchase flows end-to-end against prod.

**Whitelist is now a full premium override**
- `auth.middleware.ts` looks up `quota_whitelist.contains(email)` in parallel with the user upsert and sets `tier = "premium"` when `user.isPremium || isWhitelisted`. Knock-on: whitelisted users unlock premium-only input types (`pdf`/`youtube`/`urls`/`book`) at `ai.routes.ts:216` and CSV export at `editor_page.dart:941`.
- `user.routes.ts` returns `isPremium: req.user!.tier === "premium"` so the client sees the same view.

**Removed `RC_BYPASS_PREMIUM` env flag**
- Dropped from `env.ts`, `.env.example`, `auth.middleware.ts`, `user.routes.ts`. Whitelist now covers all "treat as premium" cases. No env knob to forget about.

---

## Recent changes (2026-05-13 session — editor back-press guard)

### Editor — discard confirmation on back press (commit `76780ee`)

- Wrapped editor `Scaffold` in `PopScope(canPop: false)` — intercepts system back gesture on iOS and Android.
- Added `_handleBackPress()` to `_EditorViewState`: pops immediately if `isDirty` is false; shows `ErrorModal("Discard changes?" / "Keep editing" / "Discard")` if dirty, pops only on Discard.
- AppBar back button now calls `_handleBackPress` instead of `Navigator.pop()` directly — both tap and swipe-back paths are covered.

---

## Recent changes (2026-05-13 session — editor response count + import fix)

### Dashboard — stale appdata file ID fix (commit `3de632a`)

- `DriveDataSource.writeImportedFormIds`: if `files.update` returns 404 (cached `gfm_data.json` was deleted externally), clears `_appDataFileId` and falls through to create a fresh file instead of propagating the error.

### Editor — response count badge on Responses tab (commit `709d810`)

- `EditorPage` now uses `MultiBlocProvider` to provide both `EditorCubit` and `ResponsesCubit`. Responses load eagerly when the editor opens (not lazily on first tab visit).
- `ResponsesScreen` no longer creates its own cubit — uses `BlocProvider.value` from the editor level.
- `_SegmentedTabBar` accepts `responseCount: int?`; renders a small frosted pill (e.g. `12`) beside "Responses" label once loaded. Hidden while loading or when count is zero.

---

## Recent changes (2026-05-13 session — drawer polish)

### Dashboard drawer — user profile banner (commit `a2892b3`)

- Replaced static "Form list" / "Google Forms Manager" header text with live user info from `SignInCubit` (`Authenticated` state).
- Added `_UserAvatar` widget: 52px circle with `NetworkImage` from `photoUrl`, falls back to initial letter.
- Shows `displayName` (bold white) and `email` (70% white) beside the avatar. Crown paywall button stays top-right.

### Dashboard drawer — Privacy Policy & Terms of Use links (commit `a4cbda0`)

- LEGAL section items now open `https://gformmanager.netlify.app/privacy` and `https://gformmanager.netlify.app/terms` in the external browser (`launchUrl externalApplication`). Same URLs as sign-in screen and paywall footer.

---

## Recent changes (2026-05-13 session — drawer polish + quota fix)

### Dashboard drawer — crown icon removed (commit `f9097cf`)
- Removed premium crown icon from drawer banner entirely.

### Dashboard drawer — "Upgrade to Premium" → "Upgrade Plan" (commit `e99faa5`)
- Renamed drawer item label.

### Backend — new user sees 0 quota on first open (commit `3423a66`)
- **Bug:** `applyFreeGrantIfDue` was only called in `POST /ai/generate`, not in `GET /user/status`. New users saw "0 generations remaining" when opening the AI builder before ever generating.
- **Fix:** `GET /user/status` now calls `applyFreeGrantIfDue` for free-tier users before reading `quota_balance`. Grant is idempotent (CTE only credits if `free_quota_reset_at IS NULL OR <= NOW()`), so calling it on every status check is safe.
- Monthly renewal is lazy/pull-based — fires on app open, no cron needed.

---

## Recent changes (2026-05-13 session — AI builder + dashboard polish)

### Dashboard — hide AppBar crown for premium/whitelisted users (commit `a974c09`)
- The drawer banner crown was removed earlier; this fix hides the second crown in the AppBar actions using `FutureBuilder<bool>` on `GetUserStatus`. Shows by default while loading, hides once `isPremium: true` resolves.

### AI builder — default question count 5 (commit `d92e63f`)
- Changed `_questionCountHint` initial value from `10` → `5`.

### AI builder — show all input tabs for free users, lock non-text (commit `7d7014b`)
- Removed `if (isPremium)` guard around `_InputTypePicker` — picker now always visible.
- `_TypeChip` gains a `locked` bool: dimmed to `0xFF8E8E93`, shows `Icons.workspace_premium` (11px) after the label, tapping opens the paywall.
- Free users: Text tab fully active; PDF / YouTube / URLs / Book locked.
- Premium/whitelisted users: all tabs fully active, no change.

---

## Recent changes (2026-05-14 session — VPS deployment + webhook fix)

### Production infrastructure setup

**Domain + VPS**
- Pointed `gfm.robi-dev.tech` (A record) to VPS IP `177.7.51.7` in Hostinger DNS
- Installed Nginx on VPS, configured reverse proxy: `gfm.robi-dev.tech:80/443` → `localhost:3002`
- Obtained Let's Encrypt SSL cert via certbot for `gfm.robi-dev.tech`

**Flutter base URL**
- `lib/features/ai_form_builder/data/datasources/ai_form_datasource.dart`: changed `_kBaseUrl` from `http://177.7.51.7:3002` → `https://gfm.robi-dev.tech` (commit `44e9afe`)

**RevenueCat webhook fix** (commit `1203e8c`)
- Webhook URL set in RevenueCat dashboard: `https://gfm.robi-dev.tech/webhooks/revenuecat`
- Bug: `webhook.routes.ts` was doing `HMAC-SHA256(rawBody, RC_WEBHOOK_SECRET)` and comparing against the Authorization header — but RevenueCat sends the secret as a plain static token, not an HMAC signature. Result: every webhook returned 401.
- Fix: replaced HMAC computation with a plain `timingSafeEqual` comparison of the provided Authorization header against `RC_WEBHOOK_SECRET`.

---

## Recent changes (2026-05-15 session — dashboard UI + iOS auth fix)

### Dashboard — nav drawer refactor
- Removed FEEDBACK / "Email us" section from nav drawer
- Added CREATE section at top of drawer with: AI Form Builder, Create Form, Import Form (same methods as FAB)
- Reduced section gaps 24→12, item vertical padding 14→10

### Dashboard — compact form list cards
- Form icon: 44×56 → 26×32
- Card vertical padding: 12 → 6
- Title font size: 15 → 13

### iOS auth fix (commit `a56a2b2`)
- **Bug:** `google_sign_in` v6 on iOS issues `idToken` with the iOS client ID as audience, not the web client ID. Backend was only accepting web client ID → all iOS users got 401 `Wrong recipient`.
- **Fix:** Added `GOOGLE_IOS_CLIENT_ID` env var; updated `google-token-verifier.ts` to accept both web and iOS client IDs as valid audiences. Added `GIDServerClientID` to `Info.plist`. Removed stale `NSAppTransportSecurity` exception for old VPS IP.
- Do NOT remove `GOOGLE_IOS_CLIENT_ID` from `.env` — iOS users will break again.

---

## Recent changes (2026-05-19 / 2026-05-20 sessions)

### Import flow — browse Drive in a WebView (commits `77d6744`, `db4ef78`)

- Replaces the manual URL-paste dialog with an in-app Google Drive WebView.
- Added `flutter_inappwebview ^6.1.5` dep (kept `webview_flutter` for the read-only preview screen).
- New `ImportFormWebViewPage` opens `https://drive.google.com/drive/u/0/search?q=type:form`.
- iOS Safari 17.5 user-agent injected via `InAppWebViewSettings.userAgent` to dodge Google's "browser not supported" banner.
- Tap detection is **not** via navigation interception — Drive's mobile UI handles form taps as in-place AJAX, no main-frame URL change to intercept. Instead, an `AT_DOCUMENT_START` userscript installs a `document`-level click handler in capture phase that walks up the DOM from the tap target looking for `data-id`, `data-target-id`, or `data-document-id`. When found, it calls `window.flutter_inappwebview.callHandler('FormTap', id)`. Flutter pops the WebView with the ID and the dashboard imports it.
- Drive's search header (the `← type:form` bar) is hidden via a stylesheet injected at document-start: `.a-s-tb-Kg, .D-B { display: none !important; }`.
- Pre-import explainer dialog ("Heads up — minimal Google Drive access…") on the dashboard before opening the WebView. Wording leads with the privacy / minimal-scope framing.

**Gotchas discovered (don't repeat):**
- `forms.google.com` no longer shows a forms list — it redirects straight to "create new form".
- WKWebView platform views leave a black artifact during route exit if disposed mid-animation. Mitigation: swap WebView for a `CupertinoActivityIndicator` via setState, wait 120 ms, then `Navigator.pop`. Pattern is in `ImportFormWebViewPage._popWithResult`.
- `flutter_inappwebview`'s `NavigationType` is unreliable on iOS (often `-1`), so don't depend on it for distinguishing user taps from redirects.

### File-upload questions via Google Forms web editor (commits `5f1292f`, `02ed4e2`, `c60bc55`, `c445609`)

- Forms API can't create or edit file-upload questions. The app now shells out to the Google Forms web editor for both create and edit:
  - **Create**: type picker → "File upload" → in-sheet prompt panel (in `QuestionEditSheet`, replaces body with a centered explainer + Continue/Cancel) → on Continue, push `EditFormWebViewPage`.
  - **Edit**: pencil on existing file-upload card → editor-level `ErrorModal` (`_showFileUploadInfoDialog`) → push `EditFormWebViewPage`.
- After WebView pops, `EditorCubit.refreshFromServer()` (public wrapper around `_silentRefresh`) reloads the form so the newly added/edited question appears.
- Two cubit signals (`fileUploadViaWebRequested`, `fileUploadEditViaWebRequested`) — BlocListener consumes them and runs `_runFileUploadWebFlow` (which skips the editor-level dialog for the add path since the in-sheet prompt already confirmed).
- `EditFormWebViewPage` hides Google Forms' fixed top chrome via injected CSS: `.vDIOnd, .MBLJ9d { display: none !important; }` and `.KP7TGc { top: 0 !important; }`. `MBLJ9d` is a spacer that reserves 146 px under the fixed header — must hide both. (DOM debug dump method is preserved in git history.)
- Both prompts dropped the user-hostile "Forms API" jargon — copy leads with the privacy / minimal-permissions framing instead.

### Editor UX overhaul (commits `48cad0e`, `aeacaf2`, `0f6a2fa`, `702dd36`)

- **Type picker redesign** — flat list of chip+text rows became iOS-style card tiles: colored icon box on the left, bold title, one-line description, purple-tinted selected state with a filled check circle. Sections relabelled from "Free-tier"/"Advanced" to "COMMON"/"ADVANCED" (the old wording was misleading post-paywall). Close icon (`×`) added in the picker's top-right.
- **Question edit sheet redesign** — flat scrolling fields became grouped iOS-style cards on a grey background. Type is now the first card (it drives what renders below it). Each card has tiny uppercase section labels. The Type row is a proper iOS row with the colored icon box and chevron. Required and Points rows gain subtitles.
- **Draft questions** — `+` no longer inserts a placeholder TextQuestion and auto-opens edit. It now opens `QuestionEditSheet` in `isDraft: true` mode with a fresh in-memory item. `Done` commits via the new `EditorCubit.addQuestionFromDraft(Item)`; dismissing the sheet discards the draft, so accidental `+` taps leave no placeholders. The old `addQuestion()` cubit method is gone.
- **File-upload type-change prompt** lives inside the QuestionEditSheet (`_FileUploadPromptPanel`) instead of closing the sheet and showing a separate dialog. Cancel restores the previous edit state.

### Drop read-only imported-form machinery (commit `fe8a2bd`)

- Imported forms (`isOwned: false`) are owned by the user (same Google account), so the Forms API lets them edit normally. Reverted commit `e337f96`: removed `EditorScope` InheritedWidget and all `if (readOnly)` branches throughout the editor tree. Net delete of ~90 lines. The API's own 403 surfaces real permission issues via the existing error modal.

### Force-pushed cleanup (2026-05-20)

- A larger refactor moving the editor's add-actions to an `ExpandableFab` and the Save button to a sticky bottom bar was force-pushed away (was: commits `4687478`, `1c32ac5`). The grading null-safety patch from that commit set was re-applied as `0e0d082`. Editor's add-actions remain the floating frosted bottom bar (Question/Image/Text/Video/Section) and Save is back as the AppBar chip.

---

## Recent changes (2026-05-20 session — RevenueCat v10 upgrade)

### RevenueCat SDK v10 migration (commits `ba0a044`, `707583c`)

**Flutter (cherry-picked from `origin/chore/revenuecat-v10-upgrade`)**
- `purchases_flutter` bumped `^8.0.0` → `^10.1.0`; `purchases_ui_flutter: ^10.1.0` added
- App ID: `appl_MkzXtKeEEhIYCwtQEgOdWquRCGK` (new RC v10 project)
- Entitlement: `gfm_premium` → `GFMPremium`
- Offering: `GFMDefault` → `default`
- `purchase()` migrated to v10 API: `Purchases.purchase(PurchaseParams.package(package))`
- iOS Podfile.lock and Xcode project synced from pod update

**Middleware**
- `webhook.routes.ts`: `event.entitlement_ids?.includes("gfm_premium")` → `"GFMPremium"` (PRODUCT_CHANGE handler — critical for correct premium state on plan change)
- `ai.routes.ts`: `requiredEntitlement` label updated to `"GFMPremium"`

**Infrastructure**
- `RC_WEBHOOK_SECRET` rotated to new value in local `.env` and deployed to VPS
- Webhook URL: `https://gfm.robi-dev.tech/webhooks/revenuecat` — test passed ✅

**Gotcha:** `deploy.sh` copies local `.env` to VPS on every deploy — always update local `.env` before deploying when secrets change, otherwise VPS gets overwritten with stale values.

---

## Recent changes (2026-05-20 session — paywall + webhook fixes)

### Premium status — post-purchase polling (commit `d6c6713`)

- Added `pollUntilPremium()` helper in `get_user_status.dart`: polls `/user/status` up to 6 retries, 3s delay after each response (~24s max wall time), calls `onPremiumConfirmed` and stops on success, gives up silently on timeout.
- **Dashboard**: `_showPaywall()` wraps `PaywallPage.show()` + `pollUntilPremium` → crown hides in same session once server confirms premium.
- **AI builder**: `_showPaywall()` replaces single `paywallDismissed()` call with `pollUntilPremium` → feature locks unlock as soon as server confirms.
- Server remains single source of truth; no RC SDK calls spread into UI layer.

### Paywall — current plan disabled (commit `433b491`)

- `SubscriptionService.getCurrentProductId()`: reads active entitlement's `productIdentifier` from RC SDK `CustomerInfo` — immediate, no webhook needed.
- `SubscriptionLoaded` state gains `currentProductId: String?` — populated in `load()`, `purchase()`, and `restore()`.
- `_currentPlan()` maps product ID → `_Plan` via `offering` package identifiers.
- Current plan card: grey (`0xFFF2F2F7`) background, non-tappable, label → `CURRENT` (side cards) / `Current` badge (annual featured card).
- Purchase button: label → "Current Plan", disabled when selected plan == current plan.
- Works immediately on paywall open; after purchase `CustomerInfo` from the purchase result updates `currentProductId` in the same state emission.

### Dashboard crown — refresh after paywall (commit `90929ac`)

- Moved `isPremiumFuture` into `_DashboardViewState`; `_refreshPremium()` resets it.
- Both paywall tap paths (AppBar crown + drawer "Upgrade Plan") now use `_showPaywall()` which polls until confirmed then calls `_refreshPremium()`.

### RevenueCat v10 + webhook fixes (commits `ba0a044`, `707583c`, `5127f36`)

- RC SDK upgraded to v10, entitlement renamed `gfm_premium` → `GFMPremium` everywhere (Flutter + middleware).
- `RC_WEBHOOK_SECRET` rotated; local `.env` updated (deploy.sh copies it — always update local `.env` before deploying).
- `PRODUCT_CHANGE` webhook now credits new plan's quota via `creditQuota` (source: `subscription_upgrade`) — previously no quota was credited on plan upgrade.

---

## Recent changes (2026-05-20 / 2026-05-21 sessions — push notifications)

End-to-end verified on Android: form response submission → Google Forms watch → Pub/Sub push → backend → FCM → device → tap deep-links into Responses tab.

### Backend (commit `f149c8d`)

- Migration `006_push_notifications.sql` — `device_tokens`, `form_watches`, `processed_pubsub_messages`.
- Domain entities + `pg-device-token.repository.ts`, `pg-form-watch.repository.ts`.
- `infrastructure/fcm/fcm.service.ts` — Firebase Admin SDK wrapper. Accepts either raw JSON or base64-encoded JSON in `FIREBASE_SERVICE_ACCOUNT_JSON` (base64 sidesteps shell-escaping issues with the private_key newlines). Multicast send, returns invalid tokens for cleanup.
- `infrastructure/google-auth/pubsub-token-verifier.ts` — OIDC verification of incoming Pub/Sub push deliveries; audience must match `FORMS_PUBSUB_AUDIENCE` env var (= the public webhook URL).
- `middleware/premium.middleware.ts` — reusable `premiumOnlyMiddleware` (403 if `req.user.tier !== "premium"`).
- Routes:
  - `POST /devices`, `DELETE /devices/:token` (authenticated)
  - `POST /watches`, `DELETE /watches/:watchId` (premium-gated)
  - `POST /webhooks/forms-watch` — Pub/Sub push handler (verified OIDC, idempotent via `processed_pubsub_messages.message_id`, fan-out across all of user's devices, deletes invalid tokens, 503 on FCM failure so Pub/Sub retries)
- `config-service.ts` now supports `string`-typed configs; `NOTIFICATION_BODY_TEMPLATE` admin-configurable (default `"You have a new response in {formTitle}"`).
- Admin UI page `NotificationsPage.tsx` for editing the template with a live preview.

### GCP / Firebase config

- GCP project: `form-manager-493310`. Pub/Sub topic: `projects/form-manager-493310/topics/forms-responses`.
- Granted `roles/pubsub.publisher` to `forms-notifications@system.gserviceaccount.com` on the topic — required by Google Forms watches.
- Push subscription `forms-responses-push` → `https://gfm.robi-dev.tech/webhooks/forms-watch`. OIDC enabled with audience = same URL. Service account is `firebase-adminsdk-fbsvc@form-manager-493310.iam.gserviceaccount.com` (any project SA works; the verifier doesn't pin email).
- APNs auth key (single `.p8`) uploaded to Firebase Console; same key serves both dev and prod since the `aps-environment` entitlement determines the APNs server.

### Flutter (commits `54ff93c`, `4aa87fc`)

- `firebase_messaging ^15.2.5`, `flutter_local_notifications ^18.0.1` (mirrors foreground messages — FCM only auto-displays in background/terminated).
- iOS: `aps-environment: development` (switch to `production` before App Store), `UIBackgroundModes: fetch, remote-notification`. Bundle ID `com.rashed.gfm` matches Firebase iOS app.
- Android: `POST_NOTIFICATIONS` permission, default FCM channel meta-data → `form_responses`, core library desugaring enabled (required by `flutter_local_notifications`). Bundle ID `com.app.formmanager` matches Firebase Android app.
- `NotificationService`:
  - `init()` runs via `unawaited()` from `main.dart` so startup isn't blocked.
  - Each step wrapped in try/catch — single hang/failure can't block the rest.
  - iOS-only `_waitForApnsToken()` polls `FirebaseMessaging.getAPNSToken()` with 10s timeout before requesting FCM token (FCM token requires APNs registration on iOS).
  - `_pendingInitialTap` field buffers a terminated-app tap until the dashboard listener attaches (broadcast streams drop events without listeners). `onNotificationTap` getter returns a `Stream.multi` that replays the pending tap to the first subscriber, then forwards live events.
- `SignInCubit` calls `registerForUser()` on sign-in (interactive and silent) and `unregisterForUser()` on sign-out (single-device cleanup; other devices stay).
- Editor settings tab: new "NOTIFICATIONS" section with `_NotificationToggle` widget. Toggle state derived from `forms.watches.list` (Google is source of truth, no local cache needed). Switch row swaps to a `CupertinoActivityIndicator` while a watch is being created/deleted to prevent layout shift and signal progress.
- `EditorPage.initialTabIndex` parameter (clamped to [0, 2]). Dashboard notification-tap handler passes `initialTabIndex: 1` so the user lands on the Responses tab.

### Polish (commit `3634aec`)

- **Admin-configurable title** — `NOTIFICATION_TITLE_TEMPLATE` added alongside `NOTIFICATION_BODY_TEMPLATE`. Both support `{formTitle}` placeholder. Webhook calls a `fillTemplate()` helper for both. Admin's Notifications page edits both side-by-side with a unified iOS-style preview card.
- **Permission rationale (soft-ask)** — `NotificationService.shouldShowRationale()` returns true iff `AuthorizationStatus.notDetermined`. Removed the auto-call to `registerForUser` from `SignInCubit` — the dashboard now owns the post-sign-in flow (via `initState` post-frame callback) so the rationale modal can show with a `BuildContext`. Modal text leads with the value ("Stay on top of new responses…") with **Enable** / **Not now** buttons. After the user taps Enable, `registerForUser()` triggers the OS-level prompt. Editor toggle also calls `registerForUser()` defensively before creating the watch in case the user dismissed the dashboard rationale and is opting in per-form.

### Responses tab action bar + toggle cache (commit `95a0838`)

- **Action bar moved into Responses tab** — Export CSV and Print now live in a new `ResponseActionsBar` widget (`lib/features/responses/presentation/widgets/response_actions_bar.dart`) positioned between the main tab bar and the Summary/Individual sub-tabs. The actions are only visible when the Responses tab is selected (previously they were above the tab bar, visible from all tabs — but that felt out of place on Questions/Settings).
- **Row-style action tiles** — 44pt-high rows with icon-left, label-right (was column with icon-on-top). The buildCsv helper moved into the same file. Settings tab no longer has the Export CSV row; DATA section only renders when a linked Sheet exists.
- **Print** — opens the form's `responderUri` externally so the user can print a blank copy for paper distribution.
- **Notification toggle cache** — `_NotificationToggle` now caches its watch state in a process-wide static map keyed by `formId`. `EditorCubit` emits `isSaving=true` on every settings change, which swaps the TabBarView for a skeleton and tears down all tab widgets — without the cache, `forms.watches.list` re-fired on every save. Cache stays in sync via writes in `_loadInitial`, `_enable`, and `_disable`. Cleared on cold-start, which is the intended invalidation point.

### Gotchas (do not repeat)

- **`echo "X='${VAR}'"` mangles JSON with `\n` in zsh** — `echo` interprets backslash escapes by default, turning the private_key's `\n` into actual newlines and breaking JSON parsing. Use base64 encoding or write the value with Python/Node instead. Codified by `fcm.service.ts` accepting both raw and base64-encoded values.
- **iOS Simulator APNs is unreliable** — even on iOS 16+ Apple Silicon, `getAPNSToken()` often returns null. Test push delivery on a real iOS device.
- **`Stream.broadcast` drops events with no listener** — for terminated-app deep-links, you must buffer the tap data until the destination widget mounts and subscribes.
- **Pub/Sub topic permission lives at topic level, not subscription** — granting `Pub/Sub Publisher` to a subscription is a no-op for Forms watches (subscriptions only have subscriber-side roles).
- **Forms watches expire after 7 days** with no renewal endpoint in the app (by user decision: most forms are short-term surveys). If a user re-enables an expired watch, a new one is created via `forms.watches.create` and the mapping is upserted by `(form_id, user_id)`.

---

## Next steps

1. ~~**Analytics + Crashlytics**~~ — ✅ Done
2. ~~**Google OAuth consent screen verification**~~ — ✅ Done (2026-05-01)
3. ~~**Template gallery**~~ — ✅ Done (2026-05-03)
4. ~~**IAP / RevenueCat**~~ — ✅ Done (commit `a355109`, 2026-05-08)
5. ~~**Quota system redesign (Q1–Q7)**~~ — ✅ Done (2026-05-11)
6. ~~**Paywall iOS redesign + product ID fix**~~ — ✅ Done (2026-05-13)
7. **UI polish** — thumb-zone audit, spacing, typography refinements
8. **App signing + store submission** — iOS provisioning, Android keystore, App Store Connect / Play Console setup
