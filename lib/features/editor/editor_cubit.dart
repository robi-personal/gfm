import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';

import '../../core/api/forms_client.dart';
import '../../core/models/form_doc.dart';

part 'editor_state.dart';

class EditorCubit extends Cubit<EditorState> {
  final FormsClient _formsClient;

  EditorCubit(this._formsClient) : super(const EditorLoading());

  Future<void> loadForm(String formId) async {
    emit(const EditorLoading());
    try {
      final apiForm = await _formsClient.api.forms.get(formId);
      final jsonMap =
          jsonDecode(jsonEncode(apiForm.toJson())) as Map<String, dynamic>;
      emit(EditorLoaded(FormDoc.fromJson(jsonMap)));
    } on SocketException {
      emit(const EditorError("Couldn't load this form.",
          kind: EditorErrorKind.network));
    } catch (e) {
      final status = _tryStatus(e);
      emit(switch (status) {
        404 => const EditorError('This form was deleted.',
            kind: EditorErrorKind.notFound),
        403 => const EditorError("You don't have access to this form.",
            kind: EditorErrorKind.permissionDenied),
        _ => const EditorError("Couldn't load this form.",
            kind: EditorErrorKind.network),
      });
    }
  }
}

int? _tryStatus(Object e) {
  try {
    return (e as dynamic).status as int?;
  } catch (_) {
    return null;
  }
}
