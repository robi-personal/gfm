part of 'editor_cubit.dart';

sealed class EditorState {
  const EditorState();
}

class EditorLoading extends EditorState {
  const EditorLoading();
}

class EditorLoaded extends EditorState {
  final FormDoc form;

  /// 'saved' | 'saving' | 'offline' | 'unpublished'
  /// Step 5: always 'saved'. Extended in step 6.
  final String saveStatus;

  const EditorLoaded(this.form, {this.saveStatus = 'saved'});

  EditorLoaded copyWith({FormDoc? form, String? saveStatus}) => EditorLoaded(
        form ?? this.form,
        saveStatus: saveStatus ?? this.saveStatus,
      );
}

class EditorError extends EditorState {
  final String message;
  final EditorErrorKind kind;

  const EditorError(this.message, {this.kind = EditorErrorKind.network});
}

enum EditorErrorKind { notFound, permissionDenied, network }
