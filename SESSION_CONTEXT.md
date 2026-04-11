# Session Context — Mobile Google Forms Companion

Read this file at the start of every session before touching any code.

---

## Build progress (steps per CLAUDE.md §12)

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
| 17–20 | ⬜ Not started | |

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

---

## Key files

```
lib/
  core/
    api/
      concurrency.dart            runBatchUpdate() + isRevisionMismatch()
      forms_client.dart           FormsApi wrapper
      drive_client.dart           DriveApi wrapper
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
        form_header_card.dart     Editable title + description
        question_card.dart        Purple left border, type chip, options preview, edit/delete buttons
        question_edit_sheet.dart  Full question edit bottom sheet
        type_chip.dart            Color-coded pill, showCaret flag
        type_picker_sheet.dart    Bottom sheet, 10 types grouped free/advanced
        section_card.dart         SectionCard + TextBlockCard + TextBlockEditSheet
        settings_sheet.dart       (legacy — not actively used; settings are inline in editor tab)
    responses/
      responses_cubit.dart        ResponsesLoading/Loaded/Error; paginated list load
      responses_screen.dart       ResponsesScreen (list) + ResponseDetailScreen (per-question answers)
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

## What NOT to do

- Do NOT add snackbars/toasts — spec §8.7 bans them. Use `ErrorModal.show()` only.
- Do NOT call `loadForm` during editing — causes full widget tree destruction.
- Do NOT use `forms.create` with items — API rejects everything except `info`.
- Do NOT hand-roll REST calls — use `package:googleapis` only.
- Do NOT skip `setPublishSettings` after create — forms are unpublished by default since March 31 2026.
- Do NOT use `identical()` for `FormDoc` equality check on item changes — `copyWith` always creates a new list reference.
- Do NOT pass null-containing maps to `googleapis` `fromJson` — always run `removeNulls` first (freezed includes null fields in `toJson`).

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

## Next steps

- **Step 17**: Duplicate form + duplicate question ← **NEXT**
- **Step 18**: Offline queue (drift-backed pending writes)
- **Step 19**: IAP integration — wire paywall purchase button; gate CSV export behind premium
- **Step 20**: Polish
- **Responses clean arch**: domain/data/presentation layers (simple — 54-line cubit)
- **Preview clean arch**: trivial move to `presentation/pages/preview_page.dart`

## Auth scopes (current)

```
drive.readonly
drive.metadata
forms.body
forms.responses.readonly
```

Decision: avoiding all restricted scopes. Will move to `drive.file` before production.
No Sheets API scope — export is CSV-only (via share_plus), linked sheet opened in browser.
