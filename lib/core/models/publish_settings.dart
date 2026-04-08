import 'package:freezed_annotation/freezed_annotation.dart';

part 'publish_settings.freezed.dart';
part 'publish_settings.g.dart';

@freezed
class PublishState with _$PublishState {
  const factory PublishState({
    @Default(false) bool isPublished,
    @Default(false) bool isAcceptingResponses,
  }) = _PublishState;

  factory PublishState.fromJson(Map<String, dynamic> json) =>
      _$PublishStateFromJson(json);
}

@freezed
class PublishSettings with _$PublishSettings {
  const factory PublishSettings({
    @Default(PublishState()) PublishState publishState,
  }) = _PublishSettings;

  factory PublishSettings.fromJson(Map<String, dynamic> json) =>
      _$PublishSettingsFromJson(json);
}
