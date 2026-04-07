# Mobile Google Forms Companion — Task List & Prompts

> Companion to `CLAUDE.md`. Each task is one Claude Code session, ending in a commit. Start fresh for every task — do not continue sessions across tasks.

---

## Model strategy for a $20 plan

- **Sonnet 4.6** is your default for ~90% of tasks.
- **Opus 4.6** is reserved for Tasks 9 and 17 where correctness is load-bearing.
- **Haiku 4.5** handles mechanical scaffolding.
- Switch inside Claude Code: `/model sonnet` / `/model opus` / `/model haiku`.

**The bigger lever than model choice is session hygiene.** A fresh session with a focused prompt burns far fewer tokens than a long session re-reading 40 files on every turn. Start fresh, let `CLAUDE.md` auto-load, end the session when the task commits.

**Three rules baked into every prompt below:**

1. **Name the files.** Stops Claude Code from exploring the codebase on every turn.
2. **Forbid unprompted work.** Every prompt ends with "do not modify other files, do not add tests unless asked, do not refactor."
3. **Commit between tasks.** Next session starts from a clean state.

---

## Architecture

Clean architecture + Cubit. Layering:

```
lib/
  core/                    # shared infra: auth, api clients, errors, DI
  features/<feature>/
    data/
      models/              # DTOs that mirror googleapis JSON
      datasources/         # remote (googleapis) + local (drift)
      repositories/        # repository impls
    domain/
      entities/            # pure Dart, no API types leaking in
      repositories/        # abstract contracts
      usecases/            # one class per action, callable
    presentation/
      cubit/               # *_cubit.dart + *_state.dart (freezed)
      pages/
      widgets/
```

Repositories return `Either<Failure, T>` (`dartz`). Cubits only talk to use cases, never repositories directly.

---

## Task 0 — Create project (no AI needed)

Do this yourself. Saves a whole session.

```bash
flutter create forms_companion --org com.yourname --platforms android,ios
cd forms_companion
# drop CLAUDE.md at the repo root
git init && git add . && git commit -m "initial flutter project + spec"
```

---

## Task 1 — Dependencies and folder scaffold

**Model:** Haiku

**Prompt:**

> Read CLAUDE.md section 2 and section 10. Add the following packages to pubspec.yaml with current stable versions: flutter_bloc, bloc, freezed, freezed_annotation, json_annotation, json_serializable, build_runner, googleapis, googleapis_auth, google_sign_in, dartz, get_it, injectable, injectable_generator, drift, drift_flutter, sqlite3_flutter_libs, path_provider, path, flutter_secure_storage, share_plus, webview_flutter, equatable. Then create the empty folder structure under lib/ exactly as in section 10, but adapted to clean architecture: lib/core/{auth,api,error,usecases,di}, lib/features/{dashboard,editor,settings,preview,responses,paywall}/{data/{models,datasources,repositories},domain/{entities,repositories,usecases},presentation/{cubit,pages,widgets}}. Create a placeholder .gitkeep in each empty folder. Do not write any Dart code beyond empty files. Do not modify main.dart. Do not run build_runner.

**Commit:** `chore: scaffold dependencies and folder structure`

---

## Task 2 — OAuth and authenticated API clients

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 2 and 3. Implement Google Sign-In and the authenticated FormsApi and DriveApi clients. Create exactly these files: lib/core/auth/google_auth_service.dart (wraps google_sign_in, returns an authenticated http.Client via googleapis_auth.authenticatedClient), lib/core/auth/auth_failure.dart (sealed class with SignInCancelled, SignInFailed, TokenExpired), lib/core/api/forms_client.dart (singleton that lazy-builds FormsApi from the authed client), lib/core/api/drive_client.dart (same for DriveApi), lib/core/di/injection.dart (get_it registrations for the auth service and both clients). Also set up the Android OAuth config: show me the exact android/app/build.gradle and strings.xml changes I need to make by hand, and the SHA-1 command. Do not build any UI. Do not create a sign-in page yet. Do not add tests.

**Commit:** `feat(core): google sign-in and authed api clients`

---

## Task 3 — Domain entities and failures

**Model:** Sonnet

> ⚠️ Do not use Haiku here. The mapping from the Forms API's sealed-union JSON to idiomatic Dart sealed classes is subtle and Haiku will flatten it.

**Prompt:**

> Read CLAUDE.md section 4 carefully. Create pure Dart domain entities using freezed sealed classes under lib/core/entities/ (shared across features). Files: form_doc.dart (FormDoc, FormInfo, FormSettings, QuizSettings, EmailCollectionType enum, PublishSettings, PublishState), item.dart (Item as a sealed class with subclasses QuestionItem, QuestionGroupItem, PageBreakItem, TextItem, ImageItem, VideoItem), question.dart (Question as a sealed class with subclasses ChoiceQuestion, TextQuestion, ScaleQuestion, DateQuestion, TimeQuestion, RatingQuestion, RowQuestion, FileUploadQuestion — even though we can't create FileUpload, we must be able to read it), option.dart, grading.dart. Also create lib/core/error/failures.dart with an abstract Failure class and concrete ServerFailure, NetworkFailure, AuthFailure, RevisionMismatchFailure, NotFoundFailure, CacheFailure. Every entity must be a freezed data class with no methods. No API imports. No JSON code in this layer — entities are pure. After writing the files, run `dart run build_runner build --delete-conflicting-outputs` and fix any generation errors. Do not create DTOs, repositories, or cubits in this task.

**Commit:** `feat(core): domain entities and failures`

---

## Task 4 — DTOs and entity mappers

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 4 and 5. In lib/features/dashboard/data/models/ and a new shared location lib/core/api/mappers/, create DTO classes and mappers that convert between googleapis `Form`, `Item`, `Question` types and the domain entities from Task 3. The DTOs are not separate classes — use the googleapis types directly as the DTO layer. Create mapper extension methods: FormExtensions.toEntity() on the googleapis Form class, ItemExtensions.toEntity() and .toApi(), QuestionExtensions for each question kind, etc. Put all mappers in lib/core/api/mappers/form_mappers.dart, item_mappers.dart, question_mappers.dart. Every mapper must handle every union case — use exhaustive switch on the sealed entity classes. Write one unit test file per mapper file under test/core/api/mappers/ using hand-written JSON fixtures (not real API calls). Fixtures go in test/fixtures/forms_api/. Keep fixtures minimal — one per question type. Do not modify entities. Do not build repositories yet.

**Commit:** `feat(core): api dtos and entity mappers`

---

## Task 5 — Dashboard repository and use cases

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md section 5.2. Build the dashboard feature's data and domain layers. Files: lib/features/dashboard/domain/repositories/dashboard_repository.dart (abstract, methods: listForms, searchForms, deleteForm, all returning Future<Either<Failure, T>>), lib/features/dashboard/domain/entities/form_summary.dart (lightweight: id, title, modifiedTime, createdTime, webViewLink — this is a domain entity, not the full FormDoc), lib/features/dashboard/domain/usecases/{list_forms.dart, search_forms.dart, delete_form.dart, open_form.dart, duplicate_form.dart}, lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart (uses DriveApi for listing/deleting and FormsApi for open), lib/features/dashboard/data/repositories/dashboard_repository_impl.dart (catches DetailedApiRequestError and maps to Failures). Implement duplicate_form.dart per CLAUDE.md section 6.2 — include the goToSectionId rewrite pass. Wire everything up in lib/core/di/injection.dart. Do not build the cubit or UI yet. Do not add tests beyond what you need to verify the duplicate flow's section-id rewrite logic.

**Commit:** `feat(dashboard): repository and use cases`

---

## Task 6 — Dashboard cubit and UI

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 5.2 and 9 (screen 2). Build the dashboard presentation layer. Files: lib/features/dashboard/presentation/cubit/dashboard_cubit.dart and dashboard_state.dart (freezed state with initial/loading/loaded(forms, sortBy, searchQuery)/error variants), lib/features/dashboard/presentation/pages/dashboard_page.dart, lib/features/dashboard/presentation/widgets/form_list_tile.dart, lib/features/dashboard/presentation/widgets/sort_toggle.dart, lib/features/dashboard/presentation/widgets/empty_state.dart. The cubit takes use cases via constructor injection. The page uses BlocProvider with get_it. Sort toggle switches between "Modified" and "Created". Search is a TextField in the app bar, debounced 300ms in the cubit. Each tile shows title, relative modified time, and an overflow menu with open/duplicate/delete/share (share just copies webViewLink for now — editor comes later). Empty state text per CLAUDE.md section 3: "Forms you create here will appear in this list." Also wire the sign-in page: lib/features/auth/presentation/pages/sign_in_page.dart with a single Google button that calls GoogleAuthService and navigates to DashboardPage on success. Set up basic routing in main.dart — MaterialApp with home showing SignInPage or DashboardPage based on auth state. Do not build the editor. Do not add tests.

**Commit:** `feat(dashboard): cubit, ui, sign-in page, routing`

**🎯 First demoable milestone** — sign in, see forms, search, delete, duplicate.

---

## Task 7 — Create form flow with publish

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md section 5.3 carefully, especially the publish requirement. Add a "Create form" use case and wire it into the dashboard FAB. Files: lib/features/dashboard/domain/usecases/create_form.dart (does forms.create, then setPublishSettings with isPublished=true and isAcceptingResponses=true, returns the new formId on success), update dashboard_remote_datasource.dart with createForm and publishForm methods, update dashboard_repository_impl.dart. In the cubit, add a createForm() method that calls the use case and emits a new state variant NavigateToEditor(formId). The page listens via BlocListener and navigates. Navigate to a placeholder EditorPage that just shows the formId — we'll build the real editor next. Verify on a real device that the created form's responderUri actually loads a responder page, not a "not accepting responses" error. Do not build editor logic. Do not add tests.

**Commit:** `feat(dashboard): create and publish new form`

---

## Task 8 — Editor read path

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 4, 5.4, and 9 (screen 3). Build the editor feature's read-only path end-to-end. Files: lib/features/editor/domain/repositories/editor_repository.dart (methods: getForm, with Future<Either<Failure, FormDoc>>), lib/features/editor/domain/usecases/get_form.dart, lib/features/editor/data/datasources/editor_remote_datasource.dart (wraps FormsApi.forms.get), lib/features/editor/data/repositories/editor_repository_impl.dart, lib/features/editor/presentation/cubit/editor_cubit.dart and editor_state.dart (states: initial, loading, loaded(FormDoc form, String cachedRevisionId), error(Failure)), lib/features/editor/presentation/pages/editor_page.dart, lib/features/editor/presentation/widgets/{form_header.dart, item_card.dart, question_card.dart, section_divider.dart, media_card.dart}. The page fetches the form on init, renders title/description in the sticky header, and renders each item in a scrollable list. question_card.dart must handle every question kind via exhaustive switch on the sealed class — show only the type label and title for now, no editing. The cached revisionId is stored in state. No editing yet — tapping a question does nothing. No add-question FAB yet. Do not modify the dashboard.

**Commit:** `feat(editor): read-only rendering of all item types`

---

## Task 9 — BatchUpdateBuilder and concurrency helper

**Model:** 🔴 **Opus** — do not cheap out here

> This is the single most important piece of infrastructure in the app. Every write flows through it. Bad concurrency logic here means data loss in production.

**Prompt:**

> Read CLAUDE.md sections 5.4 and 6 carefully. Build lib/core/api/batch_update_builder.dart: a fluent builder that produces a BatchUpdateFormRequest. API: `BatchUpdateBuilder(revisionId).updateFormInfo(title: ..., description: ...).createItem(item, atIndex: ...).updateItem(item, updateMask: ...).deleteItem(atIndex: ...).moveItem(from: ..., to: ...).updateSettings(...).build()`. Each method appends a sub-request. .build() returns a BatchUpdateFormRequest with writeControl.requiredRevisionId set. Also build lib/core/api/concurrency.dart: a `runWithRevision<T>({required Future<T> Function() action, required Future<void> Function() onRevisionMismatch, int maxRetries = 1})` helper that catches DetailedApiRequestError with status 400 + "revision" in the message, calls onRevisionMismatch (which should re-fetch the form), and retries the action exactly once. If the second attempt also fails with revision mismatch, return a RevisionMismatchFailure to the caller. Write unit tests for both: batch_update_builder_test.dart verifies every sub-request type is serialized correctly using the googleapis types, concurrency_test.dart uses a fake that throws revision mismatch once then succeeds. Do not modify the editor yet. Do not modify entities. Keep this file self-contained — no dependencies on features/.

**Commit:** `feat(core): batch update builder and revision concurrency`

---

## Task 10 — Editor write path for title and description

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 5.4, 8, and 9 (principles 4 and 5). Extend the editor repository and cubit to support editing the form title and description. This task establishes the pattern every later edit will follow, so get it right. Add to EditorRepository: `updateFormInfo({required String formId, required String revisionId, String? title, String? description})`. Implement it in the datasource using BatchUpdateBuilder from Task 9, wrapped in runWithRevision. On revision mismatch, follow §8.2 "Revision mismatch (first occurrence)" — silent retry. In the cubit, add a `debouncedUpdateInfo({String? title, String? description})` method that debounces 600ms using a Timer, then fires the repository call. State must expose a SaveStatus enum (idle, saving, saved, retrying, error) that the header widget displays as the save-status pill per §8.1. Update form_header.dart to have editable TextFields for title and description wired to the cubit. On successful update, update the in-memory form and the cachedRevisionId from the API response. On any write failure, follow the exact rollback rules in §8.3 including the editGeneration check in rule 5, and pick the surface from the matching row in §8.2. Do not invent new error surfaces — §8.1 has five, that is the complete set. Do not add question editing yet. Do not add tests.

**Commit:** `feat(editor): edit title and description with debounce and concurrency`

---

## Task 11 — Add, delete, reorder, and duplicate questions

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 5.4, 5.5, 6.1, 8, and 9 (principles 1, 2, 9). Extend EditorRepository with: addQuestion (inserts a default short-answer TextQuestion at a given index), deleteItem, moveItem, duplicateItem (per section 6.1 — deep copy, strip IDs, createItem at sourceIndex+1). All four methods use BatchUpdateBuilder + runWithRevision. In the cubit, add corresponding methods. All four must be optimistic: update local state first (incrementing editGeneration per §8.3 rule 5), fire the API call, roll back on terminal failure per §8.3. On any write failure, surface per the matching row in §8.2 — do not invent new error surfaces. The editor page needs: a bottom bar with "+ Add question" that calls cubit.addQuestion() appending at the end, long-press-to-drag on question_card using ReorderableListView that fires cubit.moveItem on drop, and an overflow menu on each card with delete and duplicate. Implement principle 1 from section 9: when a new form is opened and it has zero items, automatically fire addQuestion() once so the user sees a focused short-answer question immediately. Do not implement editing question content, changing type, or adding options yet. Do not add tests.

**Commit:** `feat(editor): add, delete, reorder, duplicate questions`

**🎯 Second demoable milestone** — structurally build a form (each question still a placeholder).

---

## Task 12 — Edit question content for all types

**Model:** Sonnet

> Big task. If Claude Code runs out of context, split at the type boundaries (text + choice in one session, scale + date + time + rating + grids in another).

**Prompt:**

> Read CLAUDE.md section 5.5 carefully — every question type and every field must be editable. Extend EditorRepository with `updateQuestion({required String formId, required String revisionId, required Item updatedItem, required String updateMask})`. Implementation uses BatchUpdateBuilder.updateItem + runWithRevision. In the cubit, add updateQuestionTitle, updateQuestionRequired, updateQuestionType (changes the question kind, preserving title and required flag, resetting type-specific fields to defaults), and per-type methods: updateChoiceOptions, updateScaleRange, updateDateFlags, updateTimeDuration, updateRatingConfig, updateGridRowsAndColumns. All debounced 600ms for text fields, immediate for toggles. Expand question_card.dart from a read-only card to an inline expanding editor: tap to expand, shows a type pill (tapping it opens a TypePickerSheet listing all 11 types per section 5.5), a title TextField, a required toggle, and a type-specific body widget. Build one body widget per type: lib/features/editor/presentation/widgets/question_bodies/{text_body.dart, choice_body.dart (with add/remove/reorder options), scale_body.dart, date_body.dart, time_body.dart, rating_body.dart, grid_body.dart}. choice_body must support the "Other" option toggle for RADIO/CHECKBOX. Do not implement branching (goToSectionId) yet. Do not implement sections yet. Do not implement quiz grading. Do not add tests.

**Commit:** `feat(editor): edit content for all question types`

---

## Task 13 — Sections and branching

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md section 5.5 (branching fields) and 5.8. Add section support: a "+ Add section" action in the bottom bar that creates a PageBreakItem via BatchUpdateBuilder.createItem. Render PageBreakItem as a distinct section_divider widget in the editor list, with its own editable title and description. For branching: in choice_body.dart, when the question is RADIO or DROP_DOWN and the form contains at least one PageBreakItem, show a "Go to section after answer" dropdown on each option. The dropdown lists: "Continue to next section", "Submit form", "Restart form", and one entry per PageBreakItem in the form ("Go to section: <title>"). Selecting an option updates the Option's goToAction or goToSectionId and fires updateQuestion. When a PageBreakItem is deleted, walk the form and clear any goToSectionId references pointing at the deleted itemId. Do not add tests.

**Commit:** `feat(editor): sections and branching`

---

## Task 14 — Form settings, preview, share

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 5.6, 5.9, 5.10, and 7. Build the settings bottom sheet, preview screen, and share action. Files: lib/features/editor/presentation/widgets/settings_sheet.dart (three controls: Collect email segmented button for DO_NOT_COLLECT/VERIFIED/RESPONDER_INPUT, Quiz mode toggle with a warning dialog before turning off, and an "Edit in browser" ListTile that opens `https://docs.google.com/forms/d/{formId}/edit` via url_launcher — add url_launcher to pubspec). The quiz mode toggle fires updateSettings via a new cubit method. The settings sheet opens from an overflow menu in the editor header. Build lib/features/preview/presentation/pages/preview_page.dart using webview_flutter to load form.responderUri. Open it from a "Preview" overflow item. Build the share action: a FAB or header button on the editor that calls Share.share(form.responderUri, subject: form.info.title). Copy link is a secondary action in the share sheet. Do not build the responses feature. Do not build the quiz answer key editor. Do not add tests.

**Commit:** `feat(editor): settings, preview, share`

**🎯 Third demoable milestone** — end-to-end form creation and sharing works.

---

## Task 15 — Responses feature

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md section 5.11. Build the responses feature as a new feature folder: lib/features/responses/{domain,data,presentation}. domain/entities/form_response.dart (id, createTime, lastSubmittedTime, respondentEmail, Map<String questionId, String displayAnswer>), domain/repositories/responses_repository.dart (listResponses with pagination, getResponse, getResponseCount), domain/usecases/{list_responses.dart, get_response.dart}, data/datasources using FormsApi.forms.responses, data/repositories/responses_repository_impl.dart, presentation/cubit/responses_cubit.dart with states (loading, loaded(responses, hasMore), error), presentation/pages/responses_page.dart (paginated list), presentation/pages/response_detail_page.dart (question-by-question view — resolve questionIds against the FormDoc passed in via constructor). Add a "Responses" button to the editor header that navigates to ResponsesPage. Add a response count badge next to it. For the count badge, list with pageSize: 1 initially and show "1+" / "99+" — do not paginate for the exact count unless the user opens the list. The answer display must handle all answer types per the FormResponse schema: textAnswers (join multiple with "; "), fileUploadAnswers (show file names or URLs), grading (show score if quiz). Do not add tests.

**Commit:** `feat(responses): list and detail views`

---

## Task 16 — Quiz mode answer key editor

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md section 5.7. Build the quiz answer key editor. When the form's settings.quizSettings.isQuiz is true, the editor must show per-question grading controls. Extend question_card.dart (or add a quiz_overlay.dart widget) so that in quiz mode each question shows: a point value TextField (integer, required, >= 0), and for choice questions a multi-select of correct answers drawn from the question's options. For text questions, show a list of acceptable answer strings (user can add multiple). Also support whenRight/whenWrong feedback text fields for choice questions, and generalFeedback for text questions. All edits go through updateQuestion with a grading updateMask. The BatchUpdateBuilder must already support this via its generic updateItem — verify and extend if not. When quiz mode is turned OFF, the API automatically deletes all grading; the cubit should warn the user in the confirmation dialog from Task 14. Do not add tests.

**Commit:** `feat(editor): quiz mode answer key editor`

---

## Task 17 — Offline queue with drift

**Model:** 🔴 **Opus** — genuinely tricky

> Writes must coalesce, replay in order, and interact correctly with the concurrency helper from Task 9.

**Prompt:**

> Read CLAUDE.md sections 8 (principle 6) and 5.4. Build an offline write queue. Files: lib/core/cache/app_database.dart (drift database), lib/core/cache/pending_writes_dao.dart (PendingWrites table: id, formId, operationJson, createdAt, attemptCount), lib/core/cache/pending_writes_repository.dart (enqueue, dequeueForForm, coalesce, clear), lib/core/network/connectivity_service.dart (wraps connectivity_plus — add to pubspec — exposes a Stream<bool> isOnline), lib/core/api/offline_aware_executor.dart. The executor wraps runWithRevision: if the device is offline at call time, serialize the BatchUpdateBuilder's request to JSON and enqueue it instead of firing; return success optimistically. On reconnect, the executor drains the queue per form: for each form, load all pending writes in order, coalesce them into a single BatchUpdateBuilder (two createItems become two sub-requests, a createItem followed by updateItem on the same logical item should merge — but keep the coalescing simple: just concatenate sub-requests in order, don't try to be clever), fetch the latest revisionId, fire one batchUpdate. On revision mismatch during replay, abort the drain for that form, re-fetch, and let the user resolve. Wire the editor cubit to use OfflineAwareExecutor instead of calling the repository directly for writes. Show an "Offline — changes will sync" banner in the editor header when disconnected. Write unit tests for pending_writes_repository (enqueue, coalesce, dequeue order) and a fake-network integration test for one full offline-to-online cycle. Do not change the dashboard.

**Commit:** `feat(core): offline write queue and replay`

---

## Task 18 — Paywall and CSV/XLSX export

**Model:** Sonnet

**Prompt:**

> Read CLAUDE.md sections 5.5 (paid tier column), 5.11, and 6.3. Build a simple local paywall (no payment processing yet — just a gating mechanism). Files: lib/core/paywall/paywall_service.dart (stores a bool isPro in flutter_secure_storage, exposes isPro getter and a debug togglePro for testing), lib/features/paywall/presentation/pages/paywall_page.dart (lists the paid features: advanced question types, quiz mode, CSV/XLSX export, describes them, has a "Upgrade" button that for now just flips the flag — stub for real IAP later). Gate the type picker in Task 12: when a free user taps a paid type (scale, date, time, rating, grids), show the paywall page instead of inserting the question. Gate the quiz mode toggle in the settings sheet. Gate the export action. Build the export: lib/features/responses/domain/usecases/export_responses.dart + data implementation that fetches all responses paginated, builds a CSV per CLAUDE.md section 6.3 (header row: Timestamp, Email, then question titles in form order; choice multi-selects joined with "; "; file upload answers as Drive URLs), writes to a temp file via path_provider, and opens Share.shareXFiles. Also implement XLSX export via the excel package (add to pubspec). Add an "Export" button to the responses page that is paywall-gated. Do not build real in-app purchases. Do not add tests.

**Commit:** `feat: paywall gating and response export`

---

## Skip until after v1

- **Polish and thumb-zone audit** — do this manually, not with Claude Code. Eyeball on your own phone, open focused sessions only for specific broken interactions.
- **Integration tests beyond Tasks 4, 9, 17** — expensive to generate and maintain while code is churning.
- **Widget tests** — same reason.

---

## Token-saving habits (summary)

- Start fresh Claude Code session per task; end at commit.
- Never continue across tasks — accumulated context is the biggest expense.
- Name files in prompts so Claude Code doesn't explore.
- Forbid unprompted work at the end of every prompt.
- Commit between tasks.
- Haiku for scaffolding, Sonnet for 90%, Opus only for Tasks 9 and 17.
- If Sonnet gets stuck for >2 turns on the same problem: stop, refine the prompt, or switch to Opus for one focused question. Don't let it thrash.

**Task 9 is the task to not cheap out on.** Every write flows through that builder. If it's wrong, you lose user data in production and spend 10× the Opus savings debugging it.
