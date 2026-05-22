part of 'questions_cubit.dart';

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

// ── Questions states ───────────────────────────────────────────────────────────

sealed class QuestionsState {
  const QuestionsState();
}

class QuestionsLoading extends QuestionsState {
  const QuestionsLoading();
}

class QuestionsLoaded extends QuestionsState {
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

  /// One-shot: set when the user picks "File upload" in the type picker.
  /// Consumed by BlocListener to launch the Google Forms web editor flow.
  final bool fileUploadViaWebRequested;

  /// One-shot: set when the user taps Edit on an existing file-upload card.
  /// Consumed by BlocListener to launch the Google Forms web editor flow
  /// (with edit-specific dialog copy).
  final bool fileUploadEditViaWebRequested;

  QuestionsLoaded(
    this.form, {
    FormDoc? lastKnownGood,
    List<String>? serverItemOrder,
    this.pending = PendingChanges.empty,
    this.isSaving = false,
    this.conflictPending = false,
    this.saveFailed = false,
    this.pendingEditItemId,
    this.fileUploadViaWebRequested = false,
    this.fileUploadEditViaWebRequested = false,
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

  QuestionsLoaded copyWith({
    FormDoc? form,
    FormDoc? lastKnownGood,
    List<String>? serverItemOrder,
    PendingChanges? pending,
    bool? isSaving,
    bool? conflictPending,
    bool? saveFailed,
    Object? pendingEditItemId = _unset,
    bool? fileUploadViaWebRequested,
    bool? fileUploadEditViaWebRequested,
  }) =>
      QuestionsLoaded(
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
        fileUploadViaWebRequested:
            fileUploadViaWebRequested ?? this.fileUploadViaWebRequested,
        fileUploadEditViaWebRequested: fileUploadEditViaWebRequested ??
            this.fileUploadEditViaWebRequested,
      );
}

class QuestionsError extends QuestionsState {
  final String message;
  final QuestionsErrorKind kind;

  const QuestionsError(this.message, {this.kind = QuestionsErrorKind.network});
}

enum QuestionsErrorKind { notFound, permissionDenied, network }
