// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publish_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PublishStateImpl _$$PublishStateImplFromJson(Map<String, dynamic> json) =>
    _$PublishStateImpl(
      isPublished: json['isPublished'] as bool? ?? false,
      isAcceptingResponses: json['isAcceptingResponses'] as bool? ?? false,
    );

Map<String, dynamic> _$$PublishStateImplToJson(_$PublishStateImpl instance) =>
    <String, dynamic>{
      'isPublished': instance.isPublished,
      'isAcceptingResponses': instance.isAcceptingResponses,
    };

_$PublishSettingsImpl _$$PublishSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$PublishSettingsImpl(
  publishState: json['publishState'] == null
      ? const PublishState()
      : PublishState.fromJson(json['publishState'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$PublishSettingsImplToJson(
  _$PublishSettingsImpl instance,
) => <String, dynamic>{'publishState': instance.publishState.toJson()};
