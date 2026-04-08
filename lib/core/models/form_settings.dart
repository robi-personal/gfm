import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'form_settings.freezed.dart';
part 'form_settings.g.dart';

@freezed
class QuizSettings with _$QuizSettings {
  const factory QuizSettings({
    @Default(false) bool isQuiz,
  }) = _QuizSettings;

  factory QuizSettings.fromJson(Map<String, dynamic> json) =>
      _$QuizSettingsFromJson(json);
}

@freezed
class FormSettings with _$FormSettings {
  const FormSettings._();

  const factory FormSettings({
    @Default(QuizSettings()) QuizSettings quizSettings,
    @_EmailCollectionTypeConverter()
    @Default(EmailCollectionType.doNotCollect)
    EmailCollectionType emailCollectionType,
  }) = _FormSettings;

  factory FormSettings.fromJson(Map<String, dynamic> json) =>
      _$FormSettingsFromJson(json);
}

class _EmailCollectionTypeConverter
    implements JsonConverter<EmailCollectionType, String?> {
  const _EmailCollectionTypeConverter();

  @override
  EmailCollectionType fromJson(String? json) =>
      EmailCollectionType.fromJson(json);

  @override
  String toJson(EmailCollectionType object) => object.toJson();
}
