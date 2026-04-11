import 'dart:developer' as dev;

import 'package:bloc/bloc.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/models/form_settings.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/form_image.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question.dart';
import '../../../../core/models/question_kind.dart';
import '../../domain/repositories/editor_repository.dart';
import '../../domain/usecases/execute_batch.dart';
import '../../domain/usecases/load_form.dart';
import '../../domain/usecases/refresh_revision.dart';
import '../../domain/usecases/update_editor_settings.dart';

part 'editor_state.dart';

class EditorCubit extends Cubit<EditorState> {
  final LoadForm _loadForm;
  final ExecuteBatch _executeBatch;
  final RefreshRevision _refreshRevision;
  final UpdateEditorSettings _updateSettings;

  EditorCubit({
    required LoadForm loadForm,
    required ExecuteBatch executeBatch,
    required RefreshRevision refreshRevision,
    required UpdateEditorSettings updateSettings,
  })  : _loadForm = loadForm,
        _executeBatch = executeBatch,
        _refreshRevision = refreshRevision,
        _updateSettings = updateSettings,
        super(const EditorLoading());

  String _revisionId = '';

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadForm(String formId) async {
    emit(const EditorLoading());
    final result = await _loadForm(formId);
    result.fold(
      (failure) => emit(switch (failure) {
        NotFoundFailure() => const EditorError(
            'This form was deleted.',
            kind: EditorErrorKind.notFound,
          ),
        PermissionFailure() => const EditorError(
            "You don't have access to this form.",
            kind: EditorErrorKind.permissionDenied,
          ),
        _ => const EditorError(
            "Couldn't load this form.",
            kind: EditorErrorKind.network,
          ),
      }),
      (doc) {
        _revisionId = doc.revisionId;
        emit(EditorLoaded(doc));
      },
    );
  }

  // ── Form info ──────────────────────────────────────────────────────────────

  void updateTitle(String title) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    emit(l.copyWith(
      form: l.form.copyWith(info: l.form.info.copyWith(title: title)),
      pending: l.pending.copyWith(
        titleDesc: (title: title, description: l.form.info.description),
      ),
    ));
  }

  void updateDescription(String description) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    emit(l.copyWith(
      form: l.form.copyWith(
          info: l.form.info.copyWith(description: description)),
      pending: l.pending.copyWith(
        titleDesc: (
          title: l.form.info.title,
          description: description,
        ),
      ),
    ));
  }

  // ── Add question ───────────────────────────────────────────────────────────

  void addQuestion({int? afterIndex}) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final insertAt =
        afterIndex != null ? afterIndex + 1 : l.form.items.length;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempId = '_pending_$ts';
    final placeholder = Item(
      itemId: tempId,
      title: 'Question',
      content: QuestionItemContent(
        question: Question(
          questionId: '_pending_q_$ts',
          kind: const TextQuestion(),
        ),
      ),
    );
    final newItems = [...l.form.items]..insert(insertAt, placeholder);
    emit(l.copyWith(
      form: l.form.copyWith(items: newItems),
      pending: l.pending.copyWith(
        creates: [...l.pending.creates, PendingCreate(tempId: tempId)],
      ),
      pendingEditItemId: tempId,
    ));
  }

  // ── Add text block ─────────────────────────────────────────────────────────

  void addTextBlock() {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final tempId = '_pending_${DateTime.now().millisecondsSinceEpoch}';
    final placeholder = Item(
      itemId: tempId,
      title: 'Text',
      content: const TextItemContent(),
    );
    final newItems = [...l.form.items, placeholder];
    emit(l.copyWith(
      form: l.form.copyWith(items: newItems),
      pending: l.pending.copyWith(
        creates: [...l.pending.creates, PendingCreate(tempId: tempId)],
      ),
      pendingEditItemId: tempId,
    ));
  }

  // ── Add video ──────────────────────────────────────────────────────────────

  void addVideoItem(String videoId, String title) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final tempId = '_pending_${DateTime.now().millisecondsSinceEpoch}';
    final placeholder = Item(
      itemId: tempId,
      title: title,
      content: VideoItemContent(
        video: FormVideo(
            youtubeUri: 'https://www.youtube.com/watch?v=$videoId'),
      ),
    );
    final newItems = [...l.form.items, placeholder];
    emit(l.copyWith(
      form: l.form.copyWith(items: newItems),
      pending: l.pending.copyWith(
        creates: [...l.pending.creates, PendingCreate(tempId: tempId)],
      ),
    ));
  }

  // ── Add section ────────────────────────────────────────────────────────────

  void addSection() {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final tempId = '_pending_${DateTime.now().millisecondsSinceEpoch}';
    final placeholder = Item(
      itemId: tempId,
      title: 'Section',
      content: const PageBreakItemContent(),
    );
    final newItems = [...l.form.items, placeholder];
    emit(l.copyWith(
      form: l.form.copyWith(items: newItems),
      pending: l.pending.copyWith(
        creates: [...l.pending.creates, PendingCreate(tempId: tempId)],
      ),
    ));
  }

  // ── Delete item ────────────────────────────────────────────────────────────

  void deleteItem(String itemId) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final newItems = l.form.items.where((i) => i.itemId != itemId).toList();
    final newEdits = {...l.pending.edits}..remove(itemId);

    if (itemId.startsWith('_pending_')) {
      // Temp item — never sent to server, just remove from creates list
      final newCreates =
          l.pending.creates.where((c) => c.tempId != itemId).toList();
      emit(l.copyWith(
        form: l.form.copyWith(items: newItems),
        pending: l.pending.copyWith(creates: newCreates, edits: newEdits),
      ));
    } else {
      // Real item — queue for server deletion at save time
      emit(l.copyWith(
        form: l.form.copyWith(items: newItems),
        pending: l.pending.copyWith(
          deletes: {...l.pending.deletes, itemId},
          edits: newEdits,
        ),
      ));
    }
  }

  // ── Move item ──────────────────────────────────────────────────────────────

  void moveItem(int fromIndex, int toIndex) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    if (l.isSaving || fromIndex == toIndex) return;
    final items = [...l.form.items];
    final item = items.removeAt(fromIndex);
    items.insert(toIndex, item);
    // Reorder is NOT tracked in pending — derived at save time from final order.
    emit(l.copyWith(form: l.form.copyWith(items: items)));
  }

  // ── Edit item (full replace, called from edit sheet on Done) ─────────────────

  void updateItemFull(Item updatedItem) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final itemId = updatedItem.itemId;
    final idx = l.form.items.indexWhere((i) => i.itemId == itemId);
    if (idx == -1) return;
    final newItems = [...l.form.items];
    newItems[idx] = updatedItem;
    // Temp items (pending creates) carry their latest content to the server
    // via the create request itself — no separate edit entry needed.
    final newPending = itemId.startsWith('_pending_')
        ? l.pending
        : l.pending.copyWith(edits: {...l.pending.edits, itemId});
    emit(l.copyWith(
      form: l.form.copyWith(items: newItems),
      pending: newPending,
    ));
  }

  /// Clears the one-shot [EditorLoaded.pendingEditItemId] signal after the
  /// edit sheet has been opened.
  void clearPendingEdit() {
    if (state is! EditorLoaded) return;
    emit((state as EditorLoaded).copyWith(pendingEditItemId: null));
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Future<void> updateSettings(FormSettings settings) async {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    final formId = l.form.formId;
    final snapshot = l;

    // Optimistic update
    emit(l.copyWith(form: l.form.copyWith(settings: settings)));

    final result = await _updateSettings(
      UpdateSettingsParams(formId: formId, settings: settings),
    );
    result.fold(
      (failure) {
        dev.log(
          '[EditorCubit] updateSettings error: $failure',
          name: 'API',
        );
        emit(snapshot.copyWith(saveFailed: true));
      },
      (_) {},
    );
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> save() async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (!loaded.isDirty || loaded.isSaving) return;

    final formId = loaded.form.formId;
    final localForm = loaded.form;
    final pending = loaded.pending;
    final snapshot = loaded;

    emit(loaded.copyWith(isSaving: true));

    try {
      // 1. Title / description
      if (pending.titleDesc case final td?) {
        await _sendBatch(formId, [
          forms_api.Request(
            updateFormInfo: forms_api.UpdateFormInfoRequest(
              info:
                  forms_api.Info(title: td.title, description: td.description),
              updateMask: 'title,description',
            ),
          ),
        ]);
      }

      // 2. Creates — sequential so we can collect tempId → realId
      final tempIdMap = <String, String>{};
      final serverCount = loaded.serverItemOrder.length;
      for (var i = 0; i < pending.creates.length; i++) {
        final create = pending.creates[i];
        final item =
            localForm.items.firstWhere((it) => it.itemId == create.tempId);
        final result = await _sendBatch(formId, [
          forms_api.Request(
            createItem: forms_api.CreateItemRequest(
              // Strip output-only IDs — the API rejects them in createItem.
              item: _toApiItemForCreate(item),
              location: forms_api.Location(index: serverCount + i),
            ),
          ),
        ]);
        if (result.createdItemId != null) {
          tempIdMap[create.tempId] = result.createdItemId!;
        }
      }

      // 3. Refresh revision + serverItemOrder (preserves local FormDoc & pending)
      await _refreshRevisionAndOrder(formId);
      final simulatedOrder = List<String>.from(
        (state as EditorLoaded).serverItemOrder,
      );

      // 4. Deletes — batch in descending index order (avoids index shift)
      if (pending.deletes.isNotEmpty) {
        final indices = pending.deletes
            .map((id) => simulatedOrder.indexOf(id))
            .where((i) => i != -1)
            .toList()
          ..sort((a, b) => b.compareTo(a));
        if (indices.isNotEmpty) {
          await _sendBatch(formId, [
            for (final idx in indices)
              forms_api.Request(
                deleteItem: forms_api.DeleteItemRequest(
                    location: forms_api.Location(index: idx)),
              ),
          ]);
          for (final id in pending.deletes) {
            simulatedOrder.remove(id);
          }
        }
      }

      // 5. Edits — batch all in one call
      final editRequests = <forms_api.Request>[];
      for (final editedId in pending.edits) {
        final realId = tempIdMap[editedId] ?? editedId;
        if (pending.deletes.contains(realId)) continue;
        final idx = simulatedOrder.indexOf(realId);
        if (idx == -1) continue;
        final item = localForm.items.firstWhere(
          (it) => it.itemId == editedId,
          orElse: () =>
              throw StateError('edited item not found in local form: $editedId'),
        );
        // If this was a temp item, swap in the real server-assigned itemId.
        final apiItem = tempIdMap.containsKey(editedId)
            ? _toApiItem(item.copyWith(itemId: tempIdMap[editedId]))
            : _toApiItem(item);
        editRequests.add(forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: apiItem,
            location: forms_api.Location(index: idx),
            updateMask: _updateMaskForItem(item),
          ),
        ));
      }
      if (editRequests.isNotEmpty) {
        await _sendBatch(formId, editRequests);
      }

      // 6. Moves — compute minimal move sequence from desired vs simulated order
      final desiredOrder = localForm.items
          .map((i) => tempIdMap[i.itemId] ?? i.itemId)
          .where((id) => !pending.deletes.contains(id))
          .toList();
      for (final (from, to) in _computeMoves(simulatedOrder, desiredOrder)) {
        await _sendBatch(formId, [
          forms_api.Request(
            moveItem: forms_api.MoveItemRequest(
              originalLocation: forms_api.Location(index: from),
              newLocation: forms_api.Location(index: to),
            ),
          ),
        ]);
        final moved = simulatedOrder.removeAt(from);
        simulatedOrder.insert(to, moved);
      }

      // 7. Final sync — replaces FormDoc with clean server state
      await _silentRefresh(formId);
    } catch (e, st) {
      dev.log('[EditorCubit] save() failed: $e',
          name: 'API', error: e, stackTrace: st);
      if (e is RevisionMismatchFailure) {
        emit(snapshot.copyWith(isSaving: false, conflictPending: true));
      } else {
        emit(snapshot.copyWith(isSaving: false, saveFailed: true));
      }
    }
  }

  // ── Conflict resolution ────────────────────────────────────────────────────

  void clearConflict() {
    if (state is EditorLoaded) {
      emit((state as EditorLoaded).copyWith(conflictPending: false));
    }
  }

  void clearSaveFailed() {
    if (state is EditorLoaded) {
      emit((state as EditorLoaded).copyWith(saveFailed: false));
    }
  }

  Future<void> resolveConflictKeepMine() async {
    if (state is! EditorLoaded) return;
    clearConflict();
    try {
      // Refresh revision so next Save attempt uses the latest server revision.
      await _refreshRevisionId((state as EditorLoaded).form.formId);
    } catch (_) {
      // If this fails, the next Save will get a mismatch and retry.
    }
  }

  Future<void> resolveConflictLoadLatest() async {
    if (state is! EditorLoaded) return;
    final formId = (state as EditorLoaded).form.formId;
    clearConflict();
    await loadForm(formId);
  }

  // ── Core send engine ───────────────────────────────────────────────────────

  /// Calls [ExecuteBatch] use case and returns [BatchUpdateResult].
  /// Folds the Either: on Left throws the [Failure] so save() catch block
  /// can handle rollback. On Right, updates [_revisionId] and returns.
  Future<BatchUpdateResult> _sendBatch(
    String formId,
    List<forms_api.Request> requests,
  ) async {
    dev.log(
      '[EditorCubit] _sendBatch → ${requests.length} request(s): '
      '${requests.map((r) => r.toJson().keys.join('+')).join(', ')}',
      name: 'API',
    );

    final either = await _executeBatch(ExecuteBatchParams(
      formId: formId,
      requests: requests,
      revisionId: _revisionId,
    ));

    return either.fold(
      (failure) => throw failure,
      (result) {
        _revisionId = result.revisionId;
        return result;
      },
    );
  }

  Future<void> _refreshRevisionId(String formId) async {
    final result = await _refreshRevision(formId);
    result.fold(
      (_) {},
      (revId) => _revisionId = revId,
    );
  }

  /// Refreshes revision + serverItemOrder without touching the local FormDoc.
  /// Called mid-save after creates complete.
  Future<void> _refreshRevisionAndOrder(String formId) async {
    try {
      final result = await _loadForm(formId);
      result.fold(
        (_) {
          // Silent — proceed with stale server order.
        },
        (doc) {
          _revisionId = doc.revisionId;
          if (state is EditorLoaded) {
            emit((state as EditorLoaded).copyWith(
              serverItemOrder: doc.items.map((i) => i.itemId).toList(),
            ));
          }
        },
      );
    } catch (_) {
      // Silent — proceed with stale server order.
    }
  }

  /// Replaces local FormDoc with the authoritative server state.
  /// Called at the end of save() to sync real IDs and clean up pending state.
  Future<void> _silentRefresh(String formId) async {
    try {
      final result = await _loadForm(formId);
      result.fold(
        (_) {
          // Silent — optimistic state remains; clear saving flag.
          if (state is EditorLoaded) {
            emit((state as EditorLoaded)
                .copyWith(pending: PendingChanges.empty, isSaving: false));
          }
        },
        (doc) {
          _revisionId = doc.revisionId;
          if (state is EditorLoaded) {
            // pending defaults to empty, isSaving defaults to false
            emit(EditorLoaded(doc, lastKnownGood: doc));
          }
        },
      );
    } catch (_) {
      // Silent — optimistic state remains; clear saving flag.
      if (state is EditorLoaded) {
        emit((state as EditorLoaded)
            .copyWith(pending: PendingChanges.empty, isSaving: false));
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  forms_api.Item _toApiItem(Item item) =>
      forms_api.Item.fromJson(_removeNulls(item.toJson()));

  /// Like [_toApiItem] but strips output-only IDs that the Forms API rejects
  /// in `createItem` requests (`itemId` on Item, `questionId` on Question).
  forms_api.Item _toApiItemForCreate(Item item) {
    final json = _removeNulls(item.toJson());
    json.remove('itemId');
    if (json['questionItem'] is Map<String, dynamic>) {
      final q = (json['questionItem'] as Map<String, dynamic>)['question'];
      if (q is Map<String, dynamic>) q.remove('questionId');
    }
    return forms_api.Item.fromJson(json);
  }

  static Map<String, dynamic> _removeNulls(Map<String, dynamic> map) {
    return Map.fromEntries(
      map.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(
                e.key,
                e.value is Map<String, dynamic>
                    ? _removeNulls(e.value as Map<String, dynamic>)
                    : e.value is List
                        ? _removeNullsFromList(e.value as List)
                        : e.value,
              )),
    );
  }

  static List<dynamic> _removeNullsFromList(List<dynamic> list) {
    return list
        .map((e) => e is Map<String, dynamic> ? _removeNulls(e) : e)
        .toList();
  }

  /// Broad update mask per item type — covers any field the user might have changed.
  static String _updateMaskForItem(Item item) => switch (item.content) {
        QuestionItemContent() => 'title,description,questionItem',
        _ => 'title,description',
      };

  /// Minimal insertion-sort move sequence to transform [current] into [desired].
  /// Returns a list of (fromIndex, toIndex) pairs to execute sequentially.
  static List<(int, int)> _computeMoves(
      List<String> current, List<String> desired) {
    final sim = List<String>.from(current);
    final moves = <(int, int)>[];
    for (var target = 0; target < desired.length; target++) {
      final id = desired[target];
      final cur = sim.indexOf(id);
      if (cur == -1 || cur == target) continue;
      moves.add((cur, target));
      sim
        ..removeAt(cur)
        ..insert(target, id);
    }
    return moves;
  }
}
