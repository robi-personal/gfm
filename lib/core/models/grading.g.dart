// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grading.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeedbackImpl _$$FeedbackImplFromJson(Map<String, dynamic> json) =>
    _$FeedbackImpl(text: json['text'] as String);

Map<String, dynamic> _$$FeedbackImplToJson(_$FeedbackImpl instance) =>
    <String, dynamic>{'text': instance.text};

_$CorrectAnswerImpl _$$CorrectAnswerImplFromJson(Map<String, dynamic> json) =>
    _$CorrectAnswerImpl(value: json['value'] as String);

Map<String, dynamic> _$$CorrectAnswerImplToJson(_$CorrectAnswerImpl instance) =>
    <String, dynamic>{'value': instance.value};

_$CorrectAnswersImpl _$$CorrectAnswersImplFromJson(Map<String, dynamic> json) =>
    _$CorrectAnswersImpl(
      answers:
          (json['answers'] as List<dynamic>?)
              ?.map((e) => CorrectAnswer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$CorrectAnswersImplToJson(
  _$CorrectAnswersImpl instance,
) => <String, dynamic>{
  'answers': instance.answers.map((e) => e.toJson()).toList(),
};

_$GradingImpl _$$GradingImplFromJson(Map<String, dynamic> json) =>
    _$GradingImpl(
      pointValue: (json['pointValue'] as num).toInt(),
      correctAnswers: json['correctAnswers'] == null
          ? null
          : CorrectAnswers.fromJson(
              json['correctAnswers'] as Map<String, dynamic>,
            ),
      whenRight: json['whenRight'] == null
          ? null
          : Feedback.fromJson(json['whenRight'] as Map<String, dynamic>),
      whenWrong: json['whenWrong'] == null
          ? null
          : Feedback.fromJson(json['whenWrong'] as Map<String, dynamic>),
      generalFeedback: json['generalFeedback'] == null
          ? null
          : Feedback.fromJson(json['generalFeedback'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$GradingImplToJson(_$GradingImpl instance) =>
    <String, dynamic>{
      'pointValue': instance.pointValue,
      'correctAnswers': instance.correctAnswers?.toJson(),
      'whenRight': instance.whenRight?.toJson(),
      'whenWrong': instance.whenWrong?.toJson(),
      'generalFeedback': instance.generalFeedback?.toJson(),
    };
