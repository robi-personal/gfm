import 'package:flutter/foundation.dart';
import 'package:googleapis/forms/v1.dart' as gf;

/// A single form submission. Mirrors `forms/v1/FormResponse`.
@immutable
class FormResponse {
  final String responseId;
  final DateTime createTime;
  final DateTime lastSubmittedTime;
  final String? respondentEmail;

  /// questionId → list of answer values (text strings or file names).
  final Map<String, List<String>> answers;

  const FormResponse({
    required this.responseId,
    required this.createTime,
    required this.lastSubmittedTime,
    this.respondentEmail,
    required this.answers,
  });

  factory FormResponse.fromApi(gf.FormResponse r) {
    final answers = <String, List<String>>{};
    r.answers?.forEach((qId, answer) {
      final values = <String>[];
      final textList = answer.textAnswers?.answers;
      if (textList != null) {
        for (final ta in textList) {
          if (ta.value != null) values.add(ta.value!);
        }
      }
      final fileList = answer.fileUploadAnswers?.answers;
      if (fileList != null) {
        for (final fa in fileList) {
          values.add(fa.fileName ?? fa.fileId ?? '(file)');
        }
      }
      if (values.isNotEmpty) answers[qId] = values;
    });
    return FormResponse(
      responseId: r.responseId!,
      createTime: DateTime.parse(r.createTime!),
      lastSubmittedTime: DateTime.parse(r.lastSubmittedTime!),
      respondentEmail: r.respondentEmail,
      answers: answers,
    );
  }
}
