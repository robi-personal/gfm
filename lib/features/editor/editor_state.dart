part of 'editor_cubit.dart';

sealed class EditorState {
  const EditorState();
}

class EditorLoading extends EditorState {
  const EditorLoading();
}

class EditorLoaded extends EditorState {
  final FormDoc form;

  /// Last version confirmed saved by the API. Used to roll back on terminal
  /// write failures — see spec §8.3.
  final FormDoc lastKnownGood;

  /// 'saved' | 'saving' | 'retrying' | 'offline' | 'unpublished'
  final String saveStatus;

  /// Set to true for exactly one emit when a second revision mismatch occurs.
  /// Consumed by BlocListener to show the conflict modal, then cleared.
  final bool conflictPending;

  EditorLoaded(
    this.form, {
    FormDoc? lastKnownGood,
    this.saveStatus = 'saved',
    this.conflictPending = false,
  }) : lastKnownGood = lastKnownGood ?? form;

  EditorLoaded copyWith({
    FormDoc? form,
    FormDoc? lastKnownGood,
    String? saveStatus,
    bool? conflictPending,
  }) =>
      EditorLoaded(
        form ?? this.form,
        lastKnownGood: lastKnownGood ?? this.lastKnownGood,
        saveStatus: saveStatus ?? this.saveStatus,
        conflictPending: conflictPending ?? this.conflictPending,
      );
}

class EditorError extends EditorState {
  final String message;
  final EditorErrorKind kind;

  const EditorError(this.message, {this.kind = EditorErrorKind.network});
}

enum EditorErrorKind { notFound, permissionDenied, network }
