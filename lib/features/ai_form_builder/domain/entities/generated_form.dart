import 'package:flutter/foundation.dart';

enum AiQuestionType {
  shortAnswer,
  paragraph,
  multipleChoice,
  checkboxes,
  dropdown,
  linearScale,
  date,
  time,
  rating,
}

AiQuestionType _parseType(String raw) {
  return switch (raw) {
    'SHORT_ANSWER' => AiQuestionType.shortAnswer,
    'PARAGRAPH' => AiQuestionType.paragraph,
    'MULTIPLE_CHOICE' => AiQuestionType.multipleChoice,
    'CHECKBOXES' => AiQuestionType.checkboxes,
    'DROPDOWN' => AiQuestionType.dropdown,
    'LINEAR_SCALE' => AiQuestionType.linearScale,
    'DATE' => AiQuestionType.date,
    'TIME' => AiQuestionType.time,
    'RATING' => AiQuestionType.rating,
    _ => throw ArgumentError('Unknown AI question type: $raw'),
  };
}

@immutable
class AiQuestion {
  final String title;
  final String? description;
  final bool required;
  final AiQuestionType type;
  final List<String>? options;
  final int? scaleMin;
  final int? scaleMax;
  final String? scaleMinLabel;
  final String? scaleMaxLabel;
  final int? ratingScale;

  const AiQuestion({
    required this.title,
    this.description,
    required this.required,
    required this.type,
    this.options,
    this.scaleMin,
    this.scaleMax,
    this.scaleMinLabel,
    this.scaleMaxLabel,
    this.ratingScale,
  });

  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>?;
    return AiQuestion(
      title: json['title'] as String,
      description: json['description'] as String?,
      required: json['required'] as bool? ?? false,
      type: _parseType(json['type'] as String),
      options: rawOptions?.map((e) => e as String).toList(),
      scaleMin: (json['scaleMin'] as num?)?.toInt(),
      scaleMax: (json['scaleMax'] as num?)?.toInt(),
      scaleMinLabel: json['scaleMinLabel'] as String?,
      scaleMaxLabel: json['scaleMaxLabel'] as String?,
      ratingScale: (json['ratingScale'] as num?)?.toInt(),
    );
  }
}

@immutable
class GeneratedForm {
  final String title;
  final String? description;
  final List<AiQuestion> questions;

  const GeneratedForm({
    required this.title,
    this.description,
    required this.questions,
  });

  factory GeneratedForm.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>;
    return GeneratedForm(
      title: json['title'] as String,
      description: json['description'] as String?,
      questions: rawQuestions
          .map((q) => AiQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}
