import '../../../../core/api/forms_client.dart';
import '../../../../core/models/form_response.dart';

class ResponsesDataSource {
  final FormsClient _client;

  ResponsesDataSource(this._client);

  /// Fetches all responses for [formId], following pagination tokens.
  /// Returns them sorted newest-first.
  Future<List<FormResponse>> getResponses(String formId) async {
    final raw = <FormResponse>[];
    String? pageToken;
    do {
      final result = await _client.api.forms.responses.list(
        formId,
        pageSize: 100,
        pageToken: pageToken,
      );
      raw.addAll((result.responses ?? []).map(FormResponse.fromApi));
      pageToken = result.nextPageToken;
    } while (pageToken != null);

    raw.sort((a, b) => b.createTime.compareTo(a.createTime));
    return raw;
  }
}
