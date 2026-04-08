import 'package:googleapis/forms/v1.dart' as forms_api;

/// Wraps a batchUpdate call with [WriteControl.requiredRevisionId] and
/// returns the new revisionId extracted from the response.
///
/// Set [includeForm] to true so the response carries the updated revisionId.
/// Callers are responsible for detecting revision-mismatch errors (HTTP 400)
/// and deciding whether to retry.
Future<String> runBatchUpdate({
  required forms_api.FormsResource api,
  required String formId,
  required String revisionId,
  required List<forms_api.Request> requests,
}) async {
  final response = await api.batchUpdate(
    forms_api.BatchUpdateFormRequest(
      requests: requests,
      writeControl: forms_api.WriteControl(
        requiredRevisionId: revisionId.isEmpty ? null : revisionId,
      ),
      includeFormInResponse: true,
    ),
    formId,
  );
  // Prefer the revisionId from the returned form; fall back to the one we sent.
  return response.form?.revisionId ?? revisionId;
}

/// Returns true when the error looks like a revision-mismatch 400.
bool isRevisionMismatch(Object e) {
  final status = _tryStatus(e);
  if (status != 400) return false;
  // googleapis puts the API error message in DetailedApiRequestError.message
  final msg = _tryMessage(e)?.toLowerCase() ?? '';
  return msg.contains('revision') || msg.contains('out of date') || msg.isEmpty;
}

int? _tryStatus(Object e) {
  try {
    return (e as dynamic).status as int?;
  } catch (_) {
    return null;
  }
}

String? _tryMessage(Object e) {
  try {
    return (e as dynamic).message as String?;
  } catch (_) {
    return null;
  }
}
