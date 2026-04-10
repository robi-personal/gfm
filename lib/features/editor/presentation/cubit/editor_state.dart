part of 'editor_cubit.dart';

// ── Pending change tracking ────────────────────────────────────────────────────

class PendingCreate {
  final String tempId;
  const PendingCreate({required this.tempId});
}

class PendingChanges {
  final ({String title, String description})? titleDesc;
  final List<PendingCreate> creates;
  final Set<String> deletes; // real item IDs only
  final Set<String> edits; // item IDs (real or temp) with mutated content

  const PendingChanges({
    this.titleDesc,
    this.creates = const [],
    this.deletes = const {},
    this.edits = const {},
  });

  bool get isDirty =>
      titleDesc != null ||
      creates.isNotEmpty ||
      deletes.isNotEmpty ||
      edits.isNotEmpty;

  static const empty = PendingChanges();

  PendingChanges copyWith({
    ({String title, String description})? titleDesc,
    List<PendingCreate>? creates,
    Set<String>? deletes,
    Set<String>? edits,
  }) =>
      PendingChanges(
        titleDesc: titleDesc ?? this.titleDesc,
        creates: creates ?? this.creates,
        deletes: deletes ?? this.deletes,
        edits: edits ?? this.edits,
      );
}

// ── Editor states ──────────────────────────────────────────────────────────────

sealed class EditorState {
  const EditorState();
}

class EditorLoading extends EditorState {
  const EditorLoading();
}

class EditorLoaded extends EditorState {
  final FormDoc form;
  final FormDoc lastKnownGood;

  /// Item IDs in the order last confirmed by the server.
  final List<String> serverItemOrder;

  final PendingChanges pending;
  final bool isSaving;

  /// Consumed by BlocListener to show the conflict modal, then cleared.
  final bool conflictPending;

  /// Consumed by BlocListener to show a save-failure modal, then cleared.
  final bool saveFailed;

  /// One-shot: set by addQuestion to auto-open the edit sheet for the new item.
  /// Cleared by clearPendingEdit() as soon as the sheet is opened.
  final String? pendingEditItemId;

  EditorLoaded(
    this.form, {
    FormDoc? lastKnownGood,
    List<String>? serverItemOrder,
    this.pending = PendingChanges.empty,
    this.isSaving = false,
    this.conflictPending = false,
    this.saveFailed = false,
    this.pendingEditItemId,
  })  : lastKnownGood = lastKnownGood ?? form,
        serverItemOrder =
            serverItemOrder ?? form.items.map((i) => i.itemId).toList();

  bool get isDirty {
    if (pending.isDirty) return true;
    final currentIds = form.items.map((i) => i.itemId).toList();
    if (currentIds.length != serverItemOrder.length) return true;
    for (var i = 0; i < currentIds.length; i++) {
      if (currentIds[i] != serverItemOrder[i]) return true;
    }
    return false;
  }

  // Sentinel that distinguishes "not passed" from "explicitly set to null".
  static const _unset = Object();

  EditorLoaded copyWith({
    FormDoc? form,
    FormDoc? lastKnownGood,
    List<String>? serverItemOrder,
    PendingChanges? pending,
    bool? isSaving,
    bool? conflictPending,
    bool? saveFailed,
    Object? pendingEditItemId = _unset,
  }) =>
      EditorLoaded(
        form ?? this.form,
        lastKnownGood: lastKnownGood ?? this.lastKnownGood,
        serverItemOrder: serverItemOrder ?? this.serverItemOrder,
        pending: pending ?? this.pending,
        isSaving: isSaving ?? this.isSaving,
        conflictPending: conflictPending ?? this.conflictPending,
        saveFailed: saveFailed ?? this.saveFailed,
        pendingEditItemId: pendingEditItemId == _unset
            ? this.pendingEditItemId
            : pendingEditItemId as String?,
      );
}

class EditorError extends EditorState {
  final String message;
  final EditorErrorKind kind;

  const EditorError(this.message, {this.kind = EditorErrorKind.network});
}

enum EditorErrorKind { notFound, permissionDenied, network }
