import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';

import '../../core/api/forms_client.dart';
import '../../core/models/form_doc.dart';

part 'form_detail_state.dart';

class FormDetailCubit extends Cubit<FormDetailState> {
  final FormsClient _formsClient;

  FormDetailCubit(this._formsClient) : super(const FormDetailLoading());

  Future<void> loadForm(String formId) async {
    emit(const FormDetailLoading());
    try {
      final apiForm = await _formsClient.api.forms.get(formId);
      // googleapis toJson() puts nested objects as Dart instances rather than
      // plain Maps. Round-tripping through jsonEncode/jsonDecode forces every
      // nested object to call its own toJson(), giving us a pure Map tree.
      final jsonMap = jsonDecode(jsonEncode(apiForm.toJson()))
          as Map<String, dynamic>;
      final doc = FormDoc.fromJson(jsonMap);
      emit(FormDetailLoaded(doc));
    } on SocketException {
      emit(const FormDetailError(
        "Couldn't load this form.",
        kind: FormDetailErrorKind.network,
      ));
    } catch (e) {
      final status = _tryGetStatus(e);
      switch (status) {
        case 404:
          emit(const FormDetailError(
            'This form was deleted.',
            kind: FormDetailErrorKind.notFound,
          ));
        case 403:
          emit(const FormDetailError(
            "You don't have access to this form.",
            kind: FormDetailErrorKind.permissionDenied,
          ));
        default:
          emit(const FormDetailError(
            "Couldn't load this form.",
            kind: FormDetailErrorKind.network,
          ));
      }
    }
  }
}

int? _tryGetStatus(Object e) {
  try {
    return (e as dynamic).status as int?;
  } catch (_) {
    return null;
  }
}
