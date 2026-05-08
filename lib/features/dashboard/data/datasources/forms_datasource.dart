import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/api/forms_client.dart';
import '../../../../core/models/item.dart' as domain;

class FormsDataSource {
  final FormsClient _client;

  FormsDataSource(this._client);

  Future<forms_api.Form> createForm(String title, {String? description}) =>
      _client.api.forms.create(
        forms_api.Form(
          info: forms_api.Info(
            title: title,
            documentTitle: title,
            description: description?.isNotEmpty == true ? description : null,
          ),
        ),
      );

  /// Sends a `forms.batchUpdate` with the given requests. Single low-level
  /// entry point used by every batch-write path (template items, AI questions,
  /// quiz-mode toggle, default question).
  Future<void> batchUpdate(
          String formId, List<forms_api.Request> requests) =>
      _client.api.forms.batchUpdate(
        forms_api.BatchUpdateFormRequest(requests: requests),
        formId,
      );

  Future<void> addDefaultQuestion(String formId) => batchUpdate(formId, [
        forms_api.Request(
          createItem: forms_api.CreateItemRequest(
            item: forms_api.Item(
              title: 'Question 1',
              questionItem: forms_api.QuestionItem(
                question: forms_api.Question(
                  required: false,
                  textQuestion: forms_api.TextQuestion(paragraph: false),
                ),
              ),
            ),
            location: forms_api.Location(index: 0),
          ),
        ),
      ]);

  /// Adds template items to a freshly created form via batchUpdate.
  /// Uses an empty revisionId (no write-control) since the form is brand new.
  Future<void> addTemplateItems(
      String formId, List<domain.Item> items) async {
    final requests = items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      // Strip itemId/questionId — API rejects output-only fields on create.
      final rawJson = _stripIds(item.toJson());
      final apiItem = forms_api.Item.fromJson(rawJson);
      return forms_api.Request(
        createItem: forms_api.CreateItemRequest(
          item: apiItem,
          location: forms_api.Location(index: index),
        ),
      );
    }).toList();

    await batchUpdate(formId, requests);
  }

  Future<void> enableQuizMode(String formId) => batchUpdate(formId, [
        forms_api.Request(
          updateSettings: forms_api.UpdateSettingsRequest(
            settings: forms_api.FormSettings(
              quizSettings: forms_api.QuizSettings(isQuiz: true),
            ),
            updateMask: 'quizSettings',
          ),
        ),
      ]);

  Future<void> publishForm(String formId) =>
      _client.api.forms.setPublishSettings(
        forms_api.SetPublishSettingsRequest(
          publishSettings: forms_api.PublishSettings(
            publishState: forms_api.PublishState(
              isPublished: true,
              isAcceptingResponses: true,
            ),
          ),
        ),
        formId,
      );
}

// Removes null-valued keys recursively (freezed toJson includes nulls;
// googleapis fromJson crashes on them) and strips output-only id fields.
Map<String, dynamic> _stripIds(Map<String, dynamic> map) {
  final clean = _removeNulls(map);
  clean.remove('itemId');
  if (clean['questionItem'] case Map<String, dynamic> qi) {
    if (qi['question'] case Map<String, dynamic> q) {
      q.remove('questionId');
    }
  }
  if (clean['questionGroupItem'] case Map<String, dynamic> qgi) {
    if (qgi['questions'] case List<dynamic> rows) {
      for (final row in rows.whereType<Map<String, dynamic>>()) {
        row.remove('questionId');
      }
    }
  }
  return clean;
}

Map<String, dynamic> _removeNulls(Map<String, dynamic> map) =>
    Map.fromEntries(
      map.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(
                e.key,
                e.value is Map<String, dynamic>
                    ? _removeNulls(e.value as Map<String, dynamic>)
                    : e.value is List
                        ? (e.value as List)
                            .map((v) => v is Map<String, dynamic>
                                ? _removeNulls(v)
                                : v)
                            .toList()
                        : e.value,
              )),
    );
