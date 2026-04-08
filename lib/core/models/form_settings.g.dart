// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QuizSettingsImpl _$$QuizSettingsImplFromJson(Map<String, dynamic> json) =>
    _$QuizSettingsImpl(isQuiz: json['isQuiz'] as bool? ?? false);

Map<String, dynamic> _$$QuizSettingsImplToJson(_$QuizSettingsImpl instance) =>
    <String, dynamic>{'isQuiz': instance.isQuiz};

_$FormSettingsImpl _$$FormSettingsImplFromJson(Map<String, dynamic> json) =>
    _$FormSettingsImpl(
      quizSettings: json['quizSettings'] == null
          ? const QuizSettings()
          : QuizSettings.fromJson(json['quizSettings'] as Map<String, dynamic>),
      emailCollectionType: json['emailCollectionType'] == null
          ? EmailCollectionType.doNotCollect
          : const _EmailCollectionTypeConverter().fromJson(
              json['emailCollectionType'] as String?,
            ),
    );

Map<String, dynamic> _$$FormSettingsImplToJson(_$FormSettingsImpl instance) =>
    <String, dynamic>{
      'quizSettings': instance.quizSettings.toJson(),
      'emailCollectionType': const _EmailCollectionTypeConverter().toJson(
        instance.emailCollectionType,
      ),
    };
