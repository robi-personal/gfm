import 'package:freezed_annotation/freezed_annotation.dart';

part 'grading.freezed.dart';
part 'grading.g.dart';

@freezed
class Feedback with _$Feedback {
  const factory Feedback({
    required String text,
    // material: List<ExtraMaterial> — omitted (view-only in v1)
  }) = _Feedback;

  factory Feedback.fromJson(Map<String, dynamic> json) =>
      _$FeedbackFromJson(json);
}

@freezed
class CorrectAnswer with _$CorrectAnswer {
  const factory CorrectAnswer({
    required String value,
  }) = _CorrectAnswer;

  factory CorrectAnswer.fromJson(Map<String, dynamic> json) =>
      _$CorrectAnswerFromJson(json);
}

@freezed
class CorrectAnswers with _$CorrectAnswers {
  const factory CorrectAnswers({
    @Default([]) List<CorrectAnswer> answers,
  }) = _CorrectAnswers;

  factory CorrectAnswers.fromJson(Map<String, dynamic> json) =>
      _$CorrectAnswersFromJson(json);
}

@freezed
class Grading with _$Grading {
  const factory Grading({
    required int pointValue,
    CorrectAnswers? correctAnswers,
    Feedback? whenRight,
    Feedback? whenWrong,
    Feedback? generalFeedback,
  }) = _Grading;

  factory Grading.fromJson(Map<String, dynamic> json) =>
      _$GradingFromJson(json);
}
