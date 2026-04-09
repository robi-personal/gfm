# Mobile Google Forms Companion — Build Spec

> **Purpose of this document.** This is the canonical context file for Claude Code. It describes *what* to build and *which Google API call backs every user action*. The vision is fixed; the scope below is the contract. Prefer this document over any assumption from general Google Forms knowledge — the Forms REST API is narrower than the browser product, and this doc is the map of what is actually buildable.

---

## 1. Vision (fixed, do not reinterpret)

A Flutter mobile app that lets users create, edit, manage, share, and review Google Forms with a **native, thumb-friendly experience that is measurably faster than using forms.google.com in a mobile browser.** The app is a *companion* to Google Forms, not a replacement. Every form the user creates lives in their own Google Drive and remains a real Google Form — editable anywhere, owned by them, synced through official Google APIs.

**North-star metric:** a user can go from cold-launch to a published 5-question form with a share link in their clipboard in under 45 seconds.

---

## 2. Tech stack (non-negotiable)

| Layer | Choice |
|---|---|
| Client | Flutter (stable channel), Dart 3.x |
| Google APIs | `package:googleapis` — `forms/v1` and `drive/v3` |
| Auth | `package:google_sign_in` + `package:googleapis_auth` (extAuthClient) |
| State | Riverpod 2.x (`flutter_riverpod`) |
| Local cache | `drift` (SQLite) for forms list + draft queue; `flutter_secure_storage` for tokens |
| HTTP | Whatever `googleapis_auth` returns — do not hand-roll REST calls |
| Sharing | `share_plus` |
| Webview (preview) | `webview_flutter` |

**Do not** add Firebase, a custom backend, or any third-party forms-wrapper package. Every write to a form must go through the official Forms API or Drive API. If a feature cannot be done through those two APIs, it is out of scope — do not work around it with scraping, Apps Script, or unofficial endpoints.

---

## 3. OAuth scopes (request exactly these)

```
https://www.googleapis.com/auth/drive.file
https://www.googleapis.com/auth/forms.body
https://www.googleapis.com/auth/forms.responses.readonly
```

- `drive.file` (not `drive`) — restricts the app to files it created or the user explicitly opened. This keeps us out of Google's restricted-scope verification process and is sufficient for everything in this spec.
- `forms.body` — create/edit form content and settings.
- `forms.responses.readonly` — list and read responses. We never write or delete responses.

**Consequence of `drive.file`:** the dashboard can only list forms the app itself created (or the user imports by pasting a link, which grants access on open). This is a deliberate trade-off. Document it in the empty-state UI: *"Forms you create here will appear in this list. To add an existing form, paste its link."*

---

## 4. Domain model

These Dart classes must mirror the Forms API schema 1:1. Use `freezed` + `json_serializable` or equivalent. Every field name below matches the REST JSON exactly.

```
FormDoc
  formId: String
  info: FormInfo { title, documentTitle, description }
  settings: FormSettings { quizSettings: { isQuiz }, emailCollectionType }
  items: List<Item>
  revisionId: String              // CRITICAL — used for optimistic concurrency
  responderUri: String            // the share link
  linkedSheetId: String?
  publishSettings: PublishSettings { publishState: { isPublished, isAcceptingResponses } }

Item
  itemId: String
  title: String?
  description: String?
  kind: one of {
    QuestionItem(question: Question, image: Image?)
    QuestionGroupItem(questions, image, grid)
    PageBreakItem                   // <-- THIS IS HOW SECTIONS WORK
    TextItem
    ImageItem(image)
    VideoItem(video, caption)
  }

Question
  questionId: String
  required: bool
  grading: Grading?                 // quiz only
  kind: one of {
    ChoiceQuestion(type: RADIO|CHECKBOX|DROP_DOWN, options, shuffle)
    TextQuestion(paragraph: bool)
    ScaleQuestion(low, high, lowLabel, highLabel)
    DateQuestion(includeTime, includeYear)
    TimeQuestion(duration: bool)
    RatingQuestion(ratingScaleLevel, iconType: STAR|HEART|THUMB_UP)
    RowQuestion                     // only inside QuestionGroupItem
    FileUploadQuestion              // READ-ONLY, see §7
  }
```

Mental model for the UI: **an Item is either a question, a section marker (`PageBreakItem`), or inert media.** A "section" in the UI is everything between two `PageBreakItem`s (or from the start of the form to the first one). Sections do not nest.

---

## 5. Features and their exact API mapping

Every row below is a feature you must implement. The "API call" column tells you exactly how. If a row says "not supported," do not implement it — the Forms API does not expose it and any attempt to fake it will break on sync.

### 5.1 Authentication & session

| Action | API call |
|---|---|
| Sign in with Google | `GoogleSignIn(scopes: [...]).signIn()` |
| Build authed client | `googleapis_auth.authenticatedClient(http.Client(), credentials)` |
| Sign out | `GoogleSignIn.signOut()` + clear local cache |
| Token refresh | handled automatically by `googleapis_auth` — do not implement manually |

### 5.2 Dashboard (form list)

| Action | API call |
|---|---|
| List forms | `DriveApi.files.list(q: "mimeType='application/vnd.google-apps.form' and trashed=false", orderBy: "modifiedTime desc", fields: "files(id,name,modifiedTime,createdTime,webViewLink)")` |
| Search forms by name | same call, append `and name contains '<query>'` to `q` |
| Sort toggle | change `orderBy` between `"modifiedTime desc"` and `"createdTime desc"` |
| Open a form (get full content) | `FormsApi.forms.get(formId)` |
| Delete form (trash) | `DriveApi.files.update(fileId, File()..trashed=true)` — prefer soft-trash over hard delete |
| Duplicate form | **Manual flow** — see §6.2 |
| Import by link | parse formId from URL, call `forms.get` (works only if user has access; `drive.file` scope grants app access on successful open) |

### 5.3 Create new form

Two-step flow. **Never** try to create items inside `forms.create` — the API rejects everything except `info`.

1. `FormsApi.forms.create(Form(info: Info(title: "Untitled form", documentTitle: "Untitled form")))`
2. *(If user adds questions before saving)* `FormsApi.forms.batchUpdate(formId, BatchUpdateFormRequest(requests: [...createItem requests...]))`
3. **Publish step (REQUIRED as of March 31, 2026):** `FormsApi.forms.setPublishSettings(formId, SetPublishSettingsRequest(publishSettings: PublishSettings(publishState: PublishState(isPublished: true, isAcceptingResponses: true))))`

Forms created via the API after March 31, 2026 are unpublished by default and their `responderUri` returns a "not accepting responses" page until published. The publish call must happen before the user sees any share affordance.

### 5.4 Edit form (the batchUpdate vocabulary)

**Everything that edits a form goes through ONE endpoint:** `forms.batchUpdate`. It accepts an array of sub-requests, applied atomically. The complete vocabulary:

| Sub-request | Use for |
|---|---|
| `updateFormInfo` | edit title or description (set `updateMask` to `"title"`, `"description"`, or `"*"`) |
| `updateSettings` | toggle quiz mode, change `emailCollectionType` |
| `createItem` | add question, section (`pageBreakItem`), text block, image, video |
| `updateItem` | edit anything about an existing item — options, required flag, question type change, etc. Always send the full item and a precise `updateMask`. |
| `deleteItem` | delete by `location.index` |
| `moveItem` | reorder — specify `originalLocation.index` and `newLocation.index` |

**Concurrency — implement this from day one, not later:**
- Cache the `revisionId` returned by the last `forms.get` or `batchUpdate`.
- On every write, set `writeControl.requiredRevisionId` to the cached value.
- If the API returns 400 "revision mismatch," re-fetch the form and retry the write once automatically (silent to the user — save-pill shows "Syncing…"). If the retry also fails, follow §8.2 "Revision mismatch (second occurrence)" — error modal with Keep/Load choice. Do not silently clobber.

**Debounce strategy:** the user types a question title → do not fire a request per keystroke. Debounce 600ms, then fire one `updateItem`. If the user makes several edits in quick succession (e.g., title + add option + mark required), coalesce them into a single `batchUpdate` with multiple sub-requests.

### 5.5 Supported item & question types (exhaustive list — build all of these)

All eight question kinds and all six item kinds the API supports. This is also the paid-tier differentiator versus the original PRD's basic five.

| UI label | Type | Notes |
|---|---|---|
| Short answer | `textQuestion { paragraph: false }` | free tier |
| Paragraph | `textQuestion { paragraph: true }` | free tier |
| Multiple choice | `choiceQuestion { type: RADIO }` | free tier |
| Checkboxes | `choiceQuestion { type: CHECKBOX }` | free tier |
| Dropdown | `choiceQuestion { type: DROP_DOWN }` | free tier |
| Linear scale | `scaleQuestion { low, high, lowLabel, highLabel }` | **paid tier** |
| Date | `dateQuestion { includeTime, includeYear }` | **paid tier** |
| Time | `timeQuestion { duration: false }` | **paid tier** |
| Duration | `timeQuestion { duration: true }` | **paid tier** |
| Rating | `ratingQuestion { ratingScaleLevel, iconType }` — levels 3–10, icons STAR/HEART/THUMB_UP | **paid tier** |
| Multiple-choice grid | `questionGroupItem { grid: { columns: RADIO } }` with `rowQuestion` children | **paid tier** |
| Checkbox grid | `questionGroupItem { grid: { columns: CHECKBOX } }` with `rowQuestion` children | **paid tier** |
| Section header | `pageBreakItem` | free tier |
| Title & description block | `textItem` | free tier |
| Image | `imageItem { image: { sourceUri } }` — source must be a public URL | free tier, view-only after create (see §7) |
| Video (YouTube) | `videoItem { video: { youtubeUri }, caption }` | free tier |

**Option fields for ChoiceQuestion:**
- `value` (string, required)
- `image` (optional — same upload caveat as image items)
- `isOther` (bool, RADIO/CHECKBOX only, not inside grids)
- `goToSectionId` or `goToAction` (RADIO and DROP_DOWN only, not inside grids) — this is how branching works

### 5.6 Form settings

| UI control | API field | Notes |
|---|---|---|
| Collect email — off | `settings.emailCollectionType = DO_NOT_COLLECT` | via `updateSettings` |
| Collect email — verified (Workspace) | `emailCollectionType = VERIFIED` | |
| Collect email — ask responder | `emailCollectionType = RESPONDER_INPUT` | |
| Make this a quiz | `settings.quizSettings.isQuiz = true` | setting to false deletes all per-question grading — warn user |
| **Limit to 1 response** | ❌ **NOT IN API** — do not build a toggle for this. If users ask, show a one-line "Edit in browser" button that opens the form's `edit` URL. |
| **Custom confirmation message** | ❌ **NOT IN API** — same treatment. |
| **Progress bar / shuffle question order (form level)** | ❌ **NOT IN API** — same treatment. |
| **Themes / colors / header image** | ❌ **NOT IN API** — same treatment. |

### 5.7 Quiz mode (enable fully — this is a key paid feature for teachers)

When `settings.quizSettings.isQuiz = true`, any `choiceQuestion` or `textQuestion` can have a `Grading` block:

```
Grading
  pointValue: int         // required, >= 0
  correctAnswers: { answers: [{ value: "..." }, ...] }
  whenRight: Feedback?    // choice questions with correct answers only
  whenWrong: Feedback?    // choice questions with correct answers only
  generalFeedback: Feedback?  // text questions; not allowed on auto-graded choice
```

Build a "Quiz mode" screen that, when toggled on, reveals per-question point values and an "Answer key" editor.

### 5.8 Branching / section navigation

For `RADIO` and `DROP_DOWN` options only, each option can carry:
- `goToAction`: `NEXT_SECTION` | `RESTART_FORM` | `SUBMIT_FORM`, OR
- `goToSectionId`: the `itemId` of a `pageBreakItem`

Surface this in the option editor as a "Go to…" dropdown that only appears when (a) the question is RADIO or DROP_DOWN and (b) the form has at least one `pageBreakItem`.

### 5.9 Preview & test submission

- "Preview" opens `form.responderUri` in an in-app `webview_flutter`.
- There is no API to submit a response programmatically. The "test submit" action is just the same webview. Do not pretend otherwise.

### 5.10 Sharing

- The share link is literally `form.responderUri`. No transformation needed.
- Copy button → clipboard.
- Share button → `Share.share(form.responderUri, subject: form.info.title)` from `share_plus`.
- **Do not** build QR codes in v1 — nice to have, defer.

### 5.11 Responses

| Action | API call |
|---|---|
| Get response count | `FormsApi.forms.responses.list(formId, pageSize: 1)` — paginate if you need the exact count; for the dashboard badge, "99+" is fine above 99 |
| List all responses | `forms.responses.list(formId, pageSize: 100)`, follow `nextPageToken` |
| Get one response | `forms.responses.get(formId, responseId)` |
| Delete a response | ❌ Not in API. Show "Open in browser" |
| Export responses (CSV) | **Manual** — see §6.3. Paid feature. |

Each `FormResponse` has: `responseId`, `createTime`, `lastSubmittedTime`, `respondentEmail` (if collected), and `answers` (map of `questionId` → `Answer`). An `Answer` contains `textAnswers.answers[].value` for text-like questions and `fileUploadAnswers` for file uploads.

---

## 6. Manual workflows (API has no dedicated endpoint)

### 6.1 Duplicate question

1. Find the source `Item` in the cached form.
2. Deep-copy it, strip `itemId` and any nested `questionId`.
3. `batchUpdate` with one `createItem` at `location.index = sourceIndex + 1`.

### 6.2 Duplicate form

1. `forms.get(sourceFormId)` → full form.
2. `forms.create(Form(info: Info(title: "Copy of " + source.info.title)))` → new `formId`.
3. Strip all `itemId`/`questionId` from `source.items`.
4. One `batchUpdate` containing:
   - `updateSettings` to copy `quizSettings` + `emailCollectionType` (if non-default),
   - one `createItem` per source item in order, each with `location.index = i`.
5. `setPublishSettings` to publish the copy.
6. Show progress UI — a 30-item form = 1 create + 1 batchUpdate + 1 publish ≈ 3 round trips, usually <2s.

**Note on fidelity:** `pageBreakItem` branching references (`goToSectionId`) point at `itemId`s that will change in the copy. After step 4, walk the new form, build a map of `oldSectionIndex → newItemId`, and issue a second `batchUpdate` that rewrites any choice option `goToSectionId` to the new IDs. Skip this rewrite only if the source form has zero branching.

### 6.3 Export responses (paid feature)

- Fetch all responses via pagination.
- Build a CSV with header row `[Timestamp, Email, <question titles in form order>]`.
- For choice questions with multiple selections, join with `; `.
- For file upload answers, write the Drive file URLs.
- Save with `path_provider`, share with `share_plus`.
- Offer `.xlsx` via `excel` Dart package for the same data — same code path, different writer.

### 6.4 Image upload for image items/options

The Forms API's `Image` object takes a `sourceUri` — a public URL. It does *not* accept base64 or multipart upload.

1. User picks an image → upload to the user's Drive via `DriveApi.files.create` with `uploadMedia`.
2. Set the uploaded file's permissions to `anyoneWithLink` via `DriveApi.permissions.create`.
3. Use the file's `webContentLink` (or a constructed `https://drive.google.com/uc?id={fileId}`) as `sourceUri`.
4. `batchUpdate` a `createItem` / `updateItem` with the `imageItem` or question `image`.

**Caveat:** there is a known API limitation where `imageItem` cannot be modified after creation via `updateItem`. To "replace" an image, delete the item and recreate it.

---

## 7. Hard API limits — things that DO NOT EXIST and we will not fake

Quote these back to anyone who asks why a feature is missing.

1. **File upload questions** — the schema exists but the docs say verbatim: *"The API currently does not support creating file upload questions."* We can *read* file upload answers from existing forms, we cannot *create* the questions.
2. **Limit to one response.**
3. **Custom confirmation message.**
4. **Response receipts / email-on-submit.**
5. **Themes, colors, fonts, header images.**
6. **Form-level question shuffle** (per-choice shuffle exists via `ChoiceQuestion.shuffle` and `Grid.shuffleQuestions`).
7. **Real-time collaboration.**
8. **Submitting responses programmatically** (read-only).
9. **Deleting responses.**
10. **Updating `imageItem` content after creation.**
11. **Updating `documentTitle` via batchUpdate** — must use Drive API `files.update`.

For items 2, 3, 4, 5, 6: add a small "Edit in browser" button on the relevant settings screen that opens `https://docs.google.com/forms/d/{formId}/edit`. This is the honest UX — don't pretend the settings don't exist, just send the user to the one place they work.

---

## 8. Error UX specification

Every failure mode the app can hit, what the user sees, and what the code does. This is a contract — do not invent new error surfaces. If a new failure mode appears, add it to this table before shipping.

### 8.1 Error surfaces (pick one per failure — not a buffet)

The app has exactly four places errors can appear. **There are no snackbars or toasts in this app.** They get missed, auto-dismissed, and leave users unsure whether their work was saved. For a form editor, that's unacceptable.

| Surface | When to use | Dismissal | Example |
|---|---|---|---|
| **Save-status pill** (in editor header) | Silent auto-retry is in progress | Auto (on next save or success) | "Retrying…" |
| **Inline banner** (top of screen, persistent) | Ambient degraded state that affects the whole screen | Manual (X button) or state change | "Offline — changes will sync when you reconnect." |
| **Error modal** (centered dialog, focused but not system-blocking) | Any user-actionable failure that needs acknowledgement or a decision | User tap only — never auto-dismiss | "Couldn't save your last change." with "Retry" / "Discard" buttons |
| **Full-screen error state** (replaces content) | The screen cannot render anything useful at all | Retry button | "Couldn't load this form." |

**Error modal anatomy** — this is the workhorse, so define it precisely:

- Centered dialog with a scrim (dimmed background). Tapping the scrim does **not** dismiss it — only explicit button taps do.
- Title: one short sentence, active voice, no exclamation marks.
- Body: one or two sentences. Explains what happened and, if relevant, what the user's options are.
- Buttons: one or two. Never three or more. The destructive or "give up" action is always on the left; the recovery action is on the right (or the only button).
- Never show raw error messages, HTTP codes, or exception names. §8.5 has copy rules.
- Icon: optional, single color (not red — red is for destructive confirmations like "delete this form"). Use a neutral warning glyph or none at all.
- A single `ErrorModal` widget in `lib/core/widgets/error_modal.dart` is the only way these are shown. No ad-hoc `showDialog` calls with error content anywhere in the codebase.

**Rule:** a single failure triggers exactly one surface. Never combine (e.g., do not show a banner *and* a modal for the same error). If you're tempted to, the failure mode is under-specified — come back and define which surface wins.

### 8.2 Failure matrix

Every failure the app can encounter. Columns: trigger → surface → user-facing copy → what the code does → retry affordance.

#### Auth failures

| Failure | Surface | Copy | Code behavior | Retry |
|---|---|---|---|---|
| Sign-in cancelled | None | (nothing) | Stay on sign-in page | User taps button again |
| Sign-in network error | Inline banner on sign-in page | "Couldn't reach Google. Check your connection." | Stay on sign-in page | Sign-in button remains active |
| Token expired mid-session | Error modal | Title: "Your session expired." Body: "Sign in again to keep editing." Buttons: "Sign in" (only) | Clear cached token, force re-auth on button tap | Modal button |
| Scope revoked (from Google account settings) | Full-screen error | "Access was removed. Sign in again to continue." | Clear session | "Sign in" button |

#### Read-path failures (dashboard, editor load, responses load)

| Failure | Surface | Copy | Code behavior | Retry |
|---|---|---|---|---|
| Dashboard list fails (offline) | Full-screen error on dashboard | "Can't load your forms. Check your connection." | Show cached list instead if one exists, with an inline banner "Showing cached list" | "Retry" button |
| Dashboard list fails (500/503) | Full-screen error | "Google Forms is having trouble. Try again in a moment." | Show cache if present | "Retry" button with 5s cooldown |
| Open form — not found (404) | Error modal | Title: "This form was deleted." Body: "It's no longer available in your Drive." Buttons: "OK" (only) | Remove from local cache, stay on dashboard | None |
| Open form — permission denied (403) | Error modal | Title: "You don't have access to this form." Body: "The owner may have revoked your access." Buttons: "OK" (only) | Keep in list but mark as inaccessible | None |
| Open form — network fail | Full-screen error on editor | "Couldn't load this form." | — | "Retry" button |
| Responses list fails | Full-screen error on responses page | "Couldn't load responses." | Keep last successful page visible if any | "Retry" button |

#### Write-path failures (every batchUpdate)

This is the hot path. Get it exactly right — the concurrency helper from Task 9 owns the retry logic, the cubit owns the UX.

| Failure | Surface | Copy | Code behavior | Retry |
|---|---|---|---|---|
| **Revision mismatch (first occurrence)** | Save-pill shows "Syncing…" briefly | (no user-visible copy) | `runWithRevision` automatically re-fetches form, merges user's pending change, retries once | Automatic, silent to user |
| **Revision mismatch (second occurrence — user edited same field on two devices)** | Error modal | Title: "This form was edited somewhere else." Body: "Keep your version or load the latest?" Buttons: "Load latest" (left) / "Keep mine" (right) | "Keep mine" → force-retry with new revisionId. "Load latest" → discard local change, refetch, update UI | User choice in modal |
| **Network offline at write time** | Inline banner on editor | "Offline — changes will sync when you reconnect." | Enqueue to drift (Task 17), update UI optimistically, save-pill shows "Offline" | Automatic on reconnect |
| **Network failure mid-flight (timeout, DNS, etc.)** | Save-pill shows "Retrying…" | (no user-visible copy for 5s) | Exponential backoff: retry after 1s, 3s, 8s | Automatic for 3 attempts |
| **Network failure — all 3 retries exhausted** | Error modal | Title: "Couldn't save your last change." Body: "Your connection dropped while saving. Retry or discard the change?" Buttons: "Discard" (left) / "Retry" (right) | On "Retry" → re-fire the request with current revisionId. On "Discard" → roll back per §8.3 | User choice in modal |
| **Server 500/503** | Save-pill + same modal as above after retries exhausted | (same) | Same backoff as network failure | Same |
| **Server 400 — invalid request (bug in our code)** | Error modal | Title: "Something went wrong." Body: "This change couldn't be saved. The app has logged the issue." Buttons: "OK" (only) | **Roll back optimistic change per §8.3.** Log full error including `updateMask` and sub-request JSON. Do not retry — 400 means deterministic failure. | None (it's a bug, not user-fixable) |
| **Server 403 — permission lost mid-edit** | Error modal, then navigate back to dashboard | Title: "You no longer have access to this form." Body: "The owner may have revoked your edit permission." Buttons: "OK" (only) | Roll back, on OK navigate to dashboard, refetch list | None |
| **Server 429 — rate limited** | Save-pill shows "Retrying…" | (silent initially) | Exponential backoff: 2s, 8s, 30s. If all three fail, escalate to error modal with "Google is rate-limiting saves right now. Your changes are preserved. Retry now?" with "Retry" button | Automatic then manual |
| **Partial batch failure** (across batches, not within one) | Error modal | Title: "Some changes couldn't be saved." Body: "Review which ones failed and retry or discard them." Buttons: "Review" (only) — opens the pending-writes review sheet | See §8.4 | See §8.4 |

#### Non-editor write failures (dashboard actions)

| Failure | Surface | Copy | Code behavior | Retry |
|---|---|---|---|---|
| Create form fails | Error modal | Title: "Couldn't create form." Body: "Check your connection and try again." Buttons: "Cancel" (left) / "Retry" (right) | No optimistic row inserted | Modal button |
| Delete form fails | Error modal | Title: "Couldn't delete this form." Body: "It's still in your list. Try again?" Buttons: "Cancel" (left) / "Retry" (right) | Roll back (re-insert in list) | Modal button |
| Duplicate form fails mid-way (create succeeded, batchUpdate failed) | Error modal | Title: "The copy was only partly created." Body: "Open it to finish manually, or delete the incomplete copy." Buttons: "Delete" (left) / "Open" (right) | Either navigate to the half-built form or trash it | User choice |
| Publish fails after successful create | Error modal | Title: "Form created but not published." Body: "Responders can't submit until it's published. Publish now?" Buttons: "Later" (left) / "Publish" (right) | Navigate to editor either way. If "Later," save-pill shows "Unpublished" until resolved | Modal button |

### 8.3 Optimistic UI rollback rules

Every write-path failure above has to either *succeed* (no UI change needed) or *roll back* (the user sees their change disappear). Rollback rules:

1. **Cubit holds both `current` and `lastKnownGood` state.** Before firing a write, `lastKnownGood = current`, then mutate `current` optimistically.
2. **On success,** `lastKnownGood = current` (commit).
3. **On terminal failure,** `current = lastKnownGood` (revert), then emit state so the UI re-renders, then show the error modal.
4. **On pending retry,** leave `current` alone. Only revert once retries are exhausted.
5. **Never roll back a value the user has edited more recently than the failed save.** If the user types "Hello" (saves, fails), then types "Hello world" before the failure surfaces, do not revert to the pre-"Hello" state.

Rule 5 is the subtle one. In practice: tag each in-flight write with a monotonic `editGeneration`. On failure, check if `state.editGeneration == failedWrite.editGeneration`. If yes, roll back. If no (user has since edited), do **not** roll back and do **not** show the modal — silently discard the failure, since the newer edit will have its own save cycle and the user doesn't need two modals. Log it (§8.6) so we can detect the pattern in support.

### 8.4 Partial batch failure — the tricky case

A `batchUpdate` with multiple sub-requests is *atomic* — per the API docs, either all sub-requests apply or none. So "partial failure" in the strict sense cannot happen inside a single batch. However:

- When the **offline queue** drains, it fires multiple batches back-to-back (one per form). Batch 1 can succeed and batch 2 can fail.
- When the **cubit coalesces** debounced edits, it may have already fired batch 1 before a new edit comes in and becomes batch 2. Same story.

So "partial failure" in practice means: *some of the user's recent edits are saved, some aren't.* Handling:

1. Keep a per-edit generation counter (§8.3, rule 5).
2. On any write failure, look at `failedWrite.editGeneration` vs `lastSuccessfulWrite.editGeneration`. The delta is the set of "lost" edits.
3. If the delta is one atomic batch's worth, use the standard write-failure error modal from §8.2.
4. If the delta is multiple batches (rare — only during offline drain), show the "Some changes couldn't be saved" modal from §8.2 which routes to a **Review sheet**: a full-screen list of pending writes, each with its own "Retry" and "Discard" action. This is a new screen, not a dialog — build it as `lib/features/editor/presentation/pages/pending_writes_review_page.dart`.
5. Do not automatically retry across batch boundaries. The user needs to know something went wrong and make a choice.

### 8.5 Copy rules

- **Never show an exception class name, HTTP code, or stack trace to the user.** Log it, don't display it.
- **Use active voice and concrete nouns.** "Couldn't load your forms" not "An error occurred."
- **Tell the user what to do next if there's anything to do.** "Check your connection" beats "Network error."
- **Never blame the user for a Google outage.** "Google Forms is having trouble" not "Your request failed."
- **Never apologize.** No "Sorry, something went wrong." Just state what happened.
- **Retry copy is always "Retry"** — never "Try again," never "Try once more." One word, used everywhere.
- **Destructive-action labels are concrete verbs.** "Discard," "Delete," "Cancel" — never "No" or "OK" for a destructive action.
- **Modal titles end with a period, not an exclamation mark.** This is a form editor, not a game.

### 8.6 Logging

Every failure surface above must log the following to the console (in debug) and to a local ring buffer (in release, for future crash reporting):

- Timestamp
- Failure class (from `Failure` sealed hierarchy)
- API method and path (if applicable)
- HTTP status (if applicable)
- `updateMask` and sub-request type (for write failures)
- `revisionId` at time of failure
- `editGeneration` (for cubit-originated failures)
- Whether a modal was shown to the user, and which one (title)

Do not log request bodies (may contain PII). Do not log OAuth tokens. Do not log response bodies for successful requests (noise).

### 8.7 What this replaces

Any earlier mention of "toast," "snackbar," or "show a toast on failure" anywhere in this spec is superseded by this section. **This app has no snackbars.** When in doubt, find the matching row in §8.2 and follow it literally. If the surface column says "Error modal," use the shared `ErrorModal` widget from §8.1 — do not invent a new dialog.

---

## 9. UX principles (these directly drive the 45-second goal)

1. **No empty state during creation.** A brand-new form already has one `textQuestion` (short answer) with the title field focused. The user is typing within one tap of "New form."
2. **Default question type = short answer.** When adding a question, don't show a type picker first — insert a short-answer question and let the user tap the type pill to change it.
3. **Inline type switcher.** Changing question type is one `updateItem` with a new `question.kind` union. Preserve the title, required flag, and (where compatible) option values.
4. **No explicit save button.** Save happens on debounce + on blur + on navigation. Show a tiny "Saved" / "Saving…" / "Offline" pill in the app bar.
5. **Optimistic UI.** Every edit updates local state immediately and queues the API call. On failure, roll back per §8.3 and surface per §8.2.
6. **Offline queue.** If the device is offline, queue `batchUpdate` requests in the drift database and replay on reconnect. Coalesce queued writes to the same form before replay.
7. **Thumb zones.** Primary actions (add question, save, share) live in the bottom 25% of the screen. The question list scrolls above. No bottom sheets that require reaching to the top to dismiss.
8. **One-tap share.** On the form detail screen, the primary FAB is "Share" — tap opens the OS share sheet with `responderUri` already loaded. Copy is a secondary action inside that sheet.
9. **Long-press = reorder.** Question cards are draggable on long-press; drop fires a single `moveItem`.

---

## 10. Screens (minimum set)

1. **Sign-in** — single Google button, legal copy, nothing else.
2. **Dashboard** — list of forms, search bar, sort toggle, FAB "New form," overflow menu per row (open, duplicate, delete, share).
3. **Form editor** — the main screen. Sticky header with form title + "Saved" pill + overflow (settings, preview, share). Scrollable list of items. Bottom bar with "+ Add question" and section/media insert.
4. **Question editor (inline, not a separate screen)** — tap a card to expand; title, type pill, options list, required toggle, delete, duplicate.
5. **Settings sheet** — collect email, quiz mode, "More settings (browser)" link.
6. **Quiz answer key editor** — only visible when quiz mode is on.
7. **Preview** — full-screen webview.
8. **Responses list** — count, list of response cards, tap opens a detail view with question-by-question answers.
9. **Paywall** — triggered when user picks a paid question type or hits export.

---

## 11. Project layout (suggested, adjust as you go)

```
lib/
  main.dart
  app.dart                       // router, theme
  core/
    auth/
      google_auth_service.dart   // google_sign_in + googleapis_auth wrapper
      auth_controller.dart       // Riverpod
    api/
      forms_client.dart          // thin wrapper around FormsApi
      drive_client.dart          // thin wrapper around DriveApi
      batch_update_builder.dart  // fluent builder for batchUpdate requests
      concurrency.dart           // revisionId tracking + retry
    cache/
      db.dart                    // drift
      forms_dao.dart
      pending_writes_dao.dart
    models/
      form_doc.dart              // freezed mirrors of the API types
      item.dart
      question.dart
  features/
    dashboard/
      dashboard_screen.dart
      dashboard_controller.dart
    editor/
      editor_screen.dart
      editor_controller.dart
      widgets/
        question_card.dart
        type_picker.dart
        option_list.dart
        section_divider.dart
    settings/
    preview/
    responses/
    paywall/
  shared/
    widgets/
    theme/
```

---

## 12. Build order (do it in this sequence — each step unblocks the next)

1. **Auth + API clients.** Sign in, build an authed `FormsApi` and `DriveApi`, print the user's form count. No UI beyond a debug screen.
2. **Dashboard read path.** List forms via Drive, tap → `forms.get` → dump JSON to the screen. Still no editor.
3. **Domain models.** Freezed classes that round-trip to/from the API JSON. Write unit tests that parse real API fixtures.
4. **Create form + publish flow.** The two-step create, then `setPublishSettings`. Confirm the `responderUri` actually accepts responses.
5. **Editor read-only.** Render questions from a fetched form. No editing yet. Get the visual language right.
6. **Editor write path — start with title/description.** `updateFormInfo` with debounce + revisionId. This is the template for all subsequent writes.
7. **Add/delete/reorder questions.** `createItem`, `deleteItem`, `moveItem`. Get optimistic UI working here; every later feature reuses this pattern.
8. **Edit question content (titles, options, required).** `updateItem` with `updateMask`.
9. **All question types.** Implement the full list from §5.5 behind a type picker.
10. **Sections + branching.** `pageBreakItem` + `goToSectionId` wiring.
11. **Form settings.** `updateSettings` + the "Edit in browser" fallback for unsupported toggles.
12. **Preview + share.** Webview + share_plus. This is when you can first demo end-to-end.
13. **Responses view.** List + detail.
14. **Quiz mode.** Per-question grading editor.
15. **Duplicate form + duplicate question.**
16. **Offline queue.** Drift-backed pending writes, replay on reconnect.
17. **Paywall + export CSV/XLSX.**
18. **Polish: thumb-zone audit, empty states, loading skeletons.** Error handling is already defined in §8 and built into every earlier step.

Do **not** start on step N+1 until step N works end-to-end on a real device with a real Google account.

---

## 13. Testing notes

- Use a throwaway Google account for integration tests. Never commit `client_secret.json`.
- Fixture every API response you parse into tests under `test/fixtures/forms_api/` — when Google changes the schema, you'll know immediately.
- `forms.batchUpdate` sub-requests are validated in order, and the whole batch is atomic. Test a batch that mixes a valid and an invalid sub-request; expect all of them to be rejected. Your UI must handle this — do not assume partial success.
- Test the revision-mismatch path by editing the same form from the browser mid-session.
- Test `drive.file` scope boundary: sign in, create a form in the app, then try to open a form created outside the app by pasting its link — it should work once the user has opened it, and fail silently before.

---

## 14. Success criteria for v1 ship

- Cold-launch → published 5-question form with link copied: **< 45 seconds** on a mid-range Android device (median across 10 trials).
- All eleven question types from §5.5 round-trip through create → edit → reload without data loss.
- Revision conflict recovery works: editing the same form in browser and app simultaneously never corrupts the form.
- Offline edits queue and replay successfully after reconnect.
- Zero unofficial API calls. Every network request goes through `package:googleapis`.
- Crash-free session rate ≥ 99.5% in beta.

---

## 15. Out of scope for v1 (explicitly)

Real-time collaboration, Firebase, custom backend, analytics dashboards beyond response count, AI question generation, templates marketplace, form-level themes, QR code sharing, widget on home screen, push notifications on new response (would require `forms.watches` + Pub/Sub — defer to v2), multi-account switcher, Workspace admin features.

---

## 16. Source of truth

- Forms API reference: https://developers.google.com/workspace/forms/api/reference/rest/v1/forms
- batchUpdate request types: https://developers.google.com/workspace/forms/api/reference/rest/v1/forms/batchUpdate
- Publish-by-default change (effective March 31, 2026): https://developers.google.com/workspace/forms/api/guides/api-changes-to-google-forms
- Drive API v3: https://developers.google.com/drive/api/v3/reference

If this spec and the official docs disagree, the official docs win. Tell the user and update this file.
