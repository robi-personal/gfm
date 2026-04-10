import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/api/forms_client.dart';

class FormsDataSource {
  final FormsClient _client;

  FormsDataSource(this._client);

  Future<forms_api.Form> createForm(String title) =>
      _client.api.forms.create(
        forms_api.Form(
          info: forms_api.Info(title: title, documentTitle: title),
        ),
      );

  Future<void> addDefaultQuestion(String formId) =>
      _client.api.forms.batchUpdate(
        forms_api.BatchUpdateFormRequest(
          requests: [
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
          ],
        ),
        formId,
      );

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
