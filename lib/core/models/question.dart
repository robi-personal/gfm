import 'package:flutter/foundation.dart';

import 'grading.dart';
import 'question_kind.dart';

/// A single question, always contained within an [Item].
/// Mirrors `forms/v1/Question` from the Forms REST API.
@immutable
class Question {
  final String questionId;
  final bool required;
  final Grading? grading;
  final QuestionKind kind;

  const Question({
    required this.questionId,
    this.required = false,
    this.grading,
    required this.kind,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        questionId: json['questionId'] as String,
        required: json['required'] as bool? ?? false,
        grading: json['grading'] == null
            ? null
            : Grading.fromJson(json['grading'] as Map<String, dynamic>),
        kind: QuestionKind.fromJson(json),
      );

  Map<String, dynamic> toJson() {
    final kindEntry = kind.toJsonEntry();
    return {
      'questionId': questionId,
      'required': required,
      if (grading != null) 'grading': grading!.toJson(),
      kindEntry.key: kindEntry.value,
    };
  }

  Question copyWith({
    String? questionId,
    bool? required,
    Grading? grading,
    QuestionKind? kind,
  }) =>
      Question(
        questionId: questionId ?? this.questionId,
        required: required ?? this.required,
        grading: grading ?? this.grading,
        kind: kind ?? this.kind,
      );

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.questionId == questionId &&
      other.required == required &&
      other.grading == grading &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(questionId, required, grading, kind);
}
