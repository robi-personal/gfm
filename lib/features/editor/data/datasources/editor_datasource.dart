import 'dart:convert';

import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/api/forms_client.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/models/form_settings.dart';
import '../../domain/repositories/editor_repository.dart';

class EditorDataSource {
  final FormsClient _client;

  EditorDataSource(this._client);

  /// Fetches a form from the API and parses it into a [FormDoc].
  /// Applies the `jsonDecode(jsonEncode(...))` round-trip fix so that
  /// nested Dart objects from `googleapis` become plain Maps before
  /// `FormDoc.fromJson` sees them.
  Future<FormDoc> getForm(String formId) async {
    final apiForm = await _client.api.forms.get(formId);
    final json =
        jsonDecode(jsonEncode(apiForm.toJson())) as Map<String, dynamic>;
    return FormDoc.fromJson(json);
  }

  /// Sends a raw batchUpdate request and returns a [BatchUpdateResult].
  /// Does NOT retry — retry logic lives in [EditorRepositoryImpl].
  Future<BatchUpdateResult> batchUpdate(
    String formId,
    List<forms_api.Request> requests,
    String revisionId,
  ) async {
    final resp = await _client.api.forms.batchUpdate(
      forms_api.BatchUpdateFormRequest(
        requests: requests,
        writeControl: forms_api.WriteControl(
          requiredRevisionId: revisionId.isEmpty ? null : revisionId,
        ),
        includeFormInResponse: true,
      ),
      formId,
    );
    return BatchUpdateResult(
      revisionId: resp.form?.revisionId ?? revisionId,
      createdItemId: resp.replies?.firstOrNull?.createItem?.itemId,
    );
  }

  /// Sends an updateSettings batchUpdate for quiz mode + email collection.
  Future<void> updateSettings(String formId, FormSettings settings) async {
    await _client.api.forms.batchUpdate(
      forms_api.BatchUpdateFormRequest(
        requests: [
          forms_api.Request(
            updateSettings: forms_api.UpdateSettingsRequest(
              settings: forms_api.FormSettings(
                quizSettings: forms_api.QuizSettings(
                    isQuiz: settings.quizSettings.isQuiz),
                emailCollectionType:
                    settings.emailCollectionType.toJson(),
              ),
              updateMask: 'quizSettings,emailCollectionType',
            ),
          ),
        ],
      ),
      formId,
    );
  }
}

// ── Null-stripping helper ─────────────────────────────────────────────────────
// freezed's toJson includes null-valued keys; googleapis fromJson crashes on them.

Map<String, dynamic> removeNulls(Map<String, dynamic> map) {
  return Map.fromEntries(
    map.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(
              e.key,
              e.value is Map<String, dynamic>
                  ? removeNulls(e.value as Map<String, dynamic>)
                  : e.value is List
                      ? _removeNullsFromList(e.value as List)
                      : e.value,
            )),
  );
}

List<dynamic> _removeNullsFromList(List<dynamic> list) =>
    list.map((e) => e is Map<String, dynamic> ? removeNulls(e) : e).toList();
