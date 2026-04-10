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
| 12 Form settings sheet | ✅ Done | `updateSettings` (quiz mode + email collection), "Edit in browser" via `url_launcher` |
| 13 Preview + Share | ✅ Done | Full-screen webview (`PreviewScreen`), `Share.share` via popup menu |
| 14 Responses list + detail | ✅ Done | `ResponsesScreen` + `ResponseDetailScreen`, paginated load, sorted newest-first |
| 15–19 | ⬜ Not started | |

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
      form_response.dart        FormResponse — responseId, createTime, respondentEmail, answers map
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
        question_card.dart      Always-expanded, fully editable, type picker integration
        type_chip.dart          Color-coded pill, showCaret flag
        type_picker_sheet.dart  Bottom sheet, 10 types grouped free/advanced
        section_card.dart       PageBreakItem + TextBlockCard
        settings_sheet.dart     Form settings (email collection, quiz mode, open-in-browser)
    responses/
      responses_cubit.dart      ResponsesLoading/Loaded/Error; paginated list load
      responses_screen.dart     ResponsesScreen (list) + ResponseDetailScreen (per-question answers)
  preview/
    preview_screen.dart         Full-screen WebViewWidget loading responderUri
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

8. **`_toApiItem` crash** (`type 'Null' is not a subtype of type 'Map<String, dynamic>'`): freezed's
   `toJson()` includes null fields (e.g. `"image": null`); `googleapis` `Option.fromJson` crashes when
   the key is present but null. Fix: `_removeNulls` helper strips all null-valued keys recursively
   before `forms_api.Item.fromJson`. Applied in `EditorCubit._toApiItem`.

9. **Scroll triggers reorder**: `ReorderableDragStartListener` started drag on any touch.
   Fix: switched to `ReorderableDelayedDragStartListener` (long-press to start drag).

10. **FocusNode double dispose**: `_QuestionCardState.dispose()` called `_titleFocusNode?.dispose()`
    on a node owned by `_TitleFieldState`. Children unmount first → double dispose → crash.
    Fix: removed dispose call from `_QuestionCardState`; `_titleFocusNode` is a borrowed reference only.

---

## Bugs fixed this session (cont.)

11. **`createItem` temp IDs**: `Item.toJson()` always emits `"itemId": "_pending_..."` and `Question.toJson()` emits `"questionId": "_pending_q_..."`. Forms API rejects these (output-only). Fix: `_toApiItemForCreate` strips both before the API call.

12. **`updateItem` temp IDs**: editing a newly created item before saving sent a temp `itemId` in the request body. Fix: substitute real server ID from `tempIdMap` before calling `_toApiItem`.

13. **400 errors retried for 12s**: non-revision 400 errors (bad request) hit the full backoff loop (1s→3s→8s). Fix: throw immediately on non-revision 400 — these won't fix themselves.

14. **Pure reorder not dirty**: `isDirty` only checked `pending`. Reorder-only changes didn't enable the Save button. Fix: `EditorLoaded.isDirty` also compares current item order vs `serverItemOrder`.

## What NOT to do

- Do NOT add snackbars/toasts — spec §8.7 bans them. Use `ErrorModal.show()` only.
- Do NOT call `loadForm` during editing — causes full widget tree destruction.
- Do NOT use `forms.create` with items — API rejects everything except `info`.
- Do NOT hand-roll REST calls — use `package:googleapis` only.
- Do NOT skip `setPublishSettings` after create — forms are unpublished by default since March 31 2026.
- Do NOT use `identical()` for `FormDoc` equality check on item changes — `copyWith` always creates a new list reference, which is what `buildWhen: !identical(prev.form, curr.form)` relies on.
- Do NOT dispose `_titleFocusNode` in `_QuestionCardState` — it is owned by `_TitleFieldState`.
- Do NOT pass null-containing maps to `googleapis` `fromJson` — always run `_removeNulls` first (freezed includes null fields in `toJson`).

---

## Deferred Save ("Save button") — design decision

**Vision:** The editor should feel instant and native — like editing a local document. Users should never feel the network while they are creating. They are in full control of when their changes are sent. Hitting Save is a deliberate, satisfying action, not an invisible background process that randomly stalls the UI.

**Problem:** API calls on every input freeze the UI (debounce doesn't help enough). Every keystroke or drag triggers a network round-trip, making the editor feel sluggish and unreliable.
**Decision:** Remove all auto-save. Track all changes locally in RAM. Add a **"Save" button** to the editor app bar. On press, flush all pending changes to the API.

### How changes are tracked (hybrid model)

| Change type | Local tracking |
|---|---|
| Title / description | Latest value only (last write wins) |
| Add item | Ordered list of creates (with temp IDs) |
| Delete item | Set of item IDs to delete |
| Edit item content | Map of `itemId → latest content` (last write wins) |
| Reorder | **Not queued** — derived at flush time from final local order vs server order |

### Flush order on Save
1. Title/desc update (`updateFormInfo`)
2. Creates — sequential, capture real server ID from each response, patch any later ops that reference the same temp ID
3. Deletes
4. Edits (with real IDs substituted for temp IDs)
5. Moves — computed by diffing final local item order against server order; simulate server state as each move is applied to keep indices correct

### Why reorders are derived, not queued
`moveItem` uses positional indices relative to current server state. Queuing raw drag events causes index drift when interleaved with creates/deletes. Deriving moves from the final order diff collapses N drags into the minimal move set and avoids index math bugs.

### Dirty state
- `EditorLoaded` gets a `isDirty` flag (true when any pending change exists)
- Save button is always visible; disabled when `!isDirty` or while flushing
- Do NOT call the button "Publish" — that term is reserved for `setPublishSettings` (Google Forms publish concept)

---

### Implementation plan (pick up here next session)

#### 1. New model — `PendingChanges` (new file or inline in `editor_state.dart`)
```dart
class PendingCreate {
  final String tempId;      // local placeholder e.g. 'tmp_1234'
  final ItemContent content; // latest content (updated in place if edited before save)
  final int insertIndex;    // position in local list at time of create
}

class PendingChanges {
  final ({String title, String description})? titleDesc; // null = unchanged
  final List<PendingCreate> creates;   // ordered
  final Set<String> deletes;           // real IDs only (temp creates deleted before save are just removed from creates)
  final Map<String, ItemContent> edits; // itemId (real or temp) → latest content
  // reorder: NOT stored here — derived at flush time
  bool get isDirty => titleDesc != null || creates.isNotEmpty || deletes.isNotEmpty || edits.isNotEmpty;
}
```

#### 2. `EditorLoaded` additions (`editor_state.dart`)
- Add `PendingChanges pending` field
- Add `List<String> serverItemOrder` — item IDs in the order last synced from server (set on `loadForm` / `_silentRefresh`, never mutated locally)
- `isDirty` → delegate to `pending.isDirty`

#### 3. `EditorCubit` changes (`editor_cubit.dart`)
- **Remove**: debounce timer, all auto-`_executeBatch` calls
- **`updateTitleDesc`**: update local `FormDoc` + set `pending.titleDesc`
- **`addItem`**: assign `tempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}'`, insert into local `FormDoc`, append to `pending.creates`
- **`deleteItem(id)`**:
  - If `id` starts with `tmp_` → remove from `pending.creates` (never hit server), done
  - Else → remove from local `FormDoc`, add to `pending.deletes`, remove from `pending.edits`
- **`editItem(id, content)`**:
  - If `id` is a temp ID → update the matching `PendingCreate.content` in place
  - Else → update local `FormDoc` + upsert `pending.edits[id]`
- **`reorderItem`**: update local `FormDoc` only — no pending entry needed
- **`save()`**: flush method (see below)

#### 4. `save()` flush algorithm (`editor_cubit.dart`)
```
emit saving state (disable Save button)
snapshot = current state for rollback

1. if pending.titleDesc != null:
     await _executeBatch([UpdateFormInfoRequest(...)])

2. tempIdMap = <String, String>{}   // tempId → realId
   for each create in pending.creates (in order):
     response = await _executeBatch([CreateItemRequest(content)])
     realId = response.replies.first.createItem.itemId
     tempIdMap[create.tempId] = realId

3. if pending.deletes.isNotEmpty:
     await _executeBatch(pending.deletes.map(DeleteItemRequest).toList())

4. resolvedEdits = pending.edits.map((id, content) =>
       MapEntry(tempIdMap[id] ?? id, content))
   if resolvedEdits.isNotEmpty:
     await _executeBatch(resolvedEdits.entries.map(UpdateItemRequest).toList())

5. compute moves:
     serverOrder = state.serverItemOrder
       .where((id) => !pending.deletes.contains(id))  // remove deleted
       .toList()
     // append newly created items in create order (they land at end server-side)
     serverOrder.addAll(pending.creates.map((c) => tempIdMap[c.tempId]!))
     desiredOrder = currentFormDoc.items.map((i) => i.id).toList()
     moves = _computeMoves(serverOrder, desiredOrder)
     for each move in moves:
       await _executeBatch([MoveItemRequest(move.originalIndex, move.newIndex)])
       // update simulated server state after each move

6. _silentRefresh()   // sync real IDs and revision
   emit clean state (pending = PendingChanges.empty)
```

#### 5. `_computeMoves` helper
Insertion-sort style: iterate `desiredOrder` left to right; if item is not already in correct position in the simulated server list, emit a `(currentIndex → targetIndex)` move and update the simulated list.

#### 6. UI changes (`editor_screen.dart`)
- Remove `saveStatus` chip / indicator from app bar
- Add `TextButton("Save")` or `IconButton(Icons.save)` to `AppBar.actions`
- Disable when `!state.isDirty || state.isSaving`
- Show `CircularProgressIndicator` in place of icon while flushing
- On error: existing `ErrorModal.show()` — rollback already handled by `_executeBatch`

---

## Next steps (step 10+)

- **Step 10**: Sections (`pageBreakItem`) + branching (`goToSectionId` on RADIO/DROP_DOWN options) ← DONE
- **Step 11**: Deferred Save ✅ Done
- **Step 12**: Form settings sheet ✅ Done
- **Step 13**: Preview + Share ✅ Done
- **Step 14**: Responses list + detail view ✅ Done
- **Step 15**: Quiz mode — per-question grading editor
- **Step 16**: Duplicate form + duplicate question
- **Step 17**: Offline queue (drift-backed pending writes)
- **Step 18**: Paywall + CSV/XLSX export
- **Step 19**: Polish
