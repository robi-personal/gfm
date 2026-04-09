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
| 5 Editor read-only | ✅ Done | `QuestionCard` expand/collapse, all item types rendered |
| 6 Editor write — title/desc | ✅ Done | 600ms debounce, `updateFormInfo`, revision mismatch retry, conflict modal |
| 7 Add/delete/reorder | ✅ Done | `createItem` / `deleteItem` / `moveItem`, optimistic UI |
| 8 Edit question content | ✅ Done | title, options, required toggle all wired |
| 9 All question types | ✅ Done | Type picker sheet, 10 types, `_mergeOptions` guarantees options |
| 10–18 | ⬜ Not started | |

---

## Critical architecture decisions

### State management
- `flutter_bloc` Cubits (NOT Riverpod — CLAUDE.md says Riverpod but codebase uses Bloc; do not change)
- `EditorCubit` holds `form` + `lastKnownGood` for rollback, `saveStatus`, `conflictPending`
- Every write: optimistic emit → `_executeBatch` → on failure `_rollback(snapshot)`

### API write pattern
Every form mutation goes through `_executeBatch` in `editor_cubit.dart`:
1. First attempt with `WriteControl.requiredRevisionId`
2. On revision mismatch (400): silent retry once after `_refreshRevisionId`
3. Second mismatch: emit `conflictPending: true` → conflict modal
4. Network/5xx: backoff 1s → 3s → 8s
5. All retries exhausted: `_rollback(snapshot)`, show error modal

### Serialization quirk — IMPORTANT
`googleapis` `Form.toJson()` puts nested Dart objects directly in the map (not plain Maps).
Fix: always `jsonDecode(jsonEncode(apiForm.toJson()))` before passing to `FormDoc.fromJson()`.
Used in: `EditorCubit.loadForm`, `EditorCubit._silentRefresh`.

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
      concurrency.dart          runBatchUpdate() + isRevisionMismatch()
      forms_client.dart         FormsApi wrapper
      drive_client.dart         DriveApi wrapper
    auth/
      google_auth_service.dart  GoogleSignIn + _GoogleAuthClient
      auth_cubit.dart
    di/injection.dart           get_it registrations
    models/
      form_doc.dart             Top-level form model
      item.dart                 Item with ItemContent sealed union
      item_content.dart         6 variants: QuestionItem, QuestionGroup, PageBreak, Text, Image, Video
      question.dart             Question with QuestionKind sealed union
      question_kind.dart        8 variants: Text, Choice, Scale, Date, Time, Rating, Row, FileUpload
      choice_option.dart        freezed, handles goToAction branching
      enums.dart                ChoiceType, RatingIconType, GoToAction, EmailCollectionType
  features/
    dashboard/
      dashboard_cubit.dart      loadForms, createForm (3-step), deleteForm
      dashboard_screen.dart
    editor/
      editor_cubit.dart         Full write path, debounce, retry engine, _silentRefresh
      editor_state.dart         EditorLoading/Loaded/Error + EditorLoaded.copyWith
      editor_screen.dart        BlocListener+BlocBuilder+BlocSelector split (no refresh bugs)
      widgets/
        form_header_card.dart   Editable title + description
        question_card.dart      Expandable, fully editable, type picker integration
        type_chip.dart          Color-coded pill, showCaret flag
        type_picker_sheet.dart  Bottom sheet, 10 types grouped free/advanced
        section_card.dart       PageBreakItem + TextBlockCard
```

---

## Bugs fixed this session (do not reintroduce)

1. **`addQuestion` refresh**: was calling `loadForm` (emits `EditorLoading` → destroys whole tree).
   Fix: `_silentRefresh` fetches form in-place without loading state.

2. **Reorder index bug**: header was at index 0 in `ReorderableListView`, offsetting all item indices.
   Fix: header moved to `SliverToBoxAdapter`, items in `SliverReorderableList` with clean 0-based indices.

3. **Save-status rebuilds**: every `saveStatus` change rebuilt entire Scaffold.
   Fix: `BlocSelector` for app bar, `buildWhen: !identical(prev.form, curr.form)` for body.

4. **ChoiceQuestion empty options**: type switch from non-choice type sent `options: []` → API 400 → silent rollback.
   Fix: `_mergeOptions` always seeds at least `[ChoiceOption(value: 'Option 1')]` when target is `ChoiceQuestion`.

5. **`FormsResourceApi`**: wrong class name in `concurrency.dart`. Correct: `FormsResource`.

6. **`explicit_to_json`**: nested freezed objects weren't calling `.toJson()`. Fix: `build.yaml` sets `explicit_to_json: true`.

7. **`googleapis` version**: `setPublishSettings` not in v13. Fixed: upgraded to `^16.0.0`.

---

## What NOT to do

- Do NOT add snackbars/toasts — spec §8.7 bans them. Use `ErrorModal.show()` only.
- Do NOT call `loadForm` during editing — causes full widget tree destruction.
- Do NOT use `forms.create` with items — API rejects everything except `info`.
- Do NOT hand-roll REST calls — use `package:googleapis` only.
- Do NOT skip `setPublishSettings` after create — forms are unpublished by default since March 31 2026.
- Do NOT use `identical()` for `FormDoc` equality check on item changes — `copyWith` always creates a new list reference, which is what `buildWhen: !identical(prev.form, curr.form)` relies on.

---

## Next steps (step 10+)

- **Step 10**: Sections (`pageBreakItem`) + branching (`goToSectionId` on RADIO/DROP_DOWN options)
- **Step 11**: Form settings sheet (`updateSettings` — quiz mode, email collection)
- **Step 12**: Preview (webview) + Share (`share_plus` with `responderUri`)
- **Step 13**: Responses list + detail view
- **Step 14**: Quiz mode — per-question grading editor
- **Step 15**: Duplicate form + duplicate question
- **Step 16**: Offline queue (drift-backed pending writes)
- **Step 17**: Paywall + CSV/XLSX export
- **Step 18**: Polish
