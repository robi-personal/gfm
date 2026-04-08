// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FormImageImpl _$$FormImageImplFromJson(Map<String, dynamic> json) =>
    _$FormImageImpl(
      contentUri: json['contentUri'] as String?,
      sourceUri: json['sourceUri'] as String?,
      altText: json['altText'] as String?,
      properties: json['properties'] == null
          ? null
          : MediaProperties.fromJson(
              json['properties'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$$FormImageImplToJson(_$FormImageImpl instance) =>
    <String, dynamic>{
      'contentUri': instance.contentUri,
      'sourceUri': instance.sourceUri,
      'altText': instance.altText,
      'properties': instance.properties?.toJson(),
    };

_$MediaPropertiesImpl _$$MediaPropertiesImplFromJson(
  Map<String, dynamic> json,
) => _$MediaPropertiesImpl(
  alignment: json['alignment'] as String?,
  width: (json['width'] as num?)?.toInt(),
);

Map<String, dynamic> _$$MediaPropertiesImplToJson(
  _$MediaPropertiesImpl instance,
) => <String, dynamic>{
  'alignment': instance.alignment,
  'width': instance.width,
};

_$FormVideoImpl _$$FormVideoImplFromJson(Map<String, dynamic> json) =>
    _$FormVideoImpl(
      youtubeUri: json['youtubeUri'] as String,
      properties: json['properties'] == null
          ? null
          : MediaProperties.fromJson(
              json['properties'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$$FormVideoImplToJson(_$FormVideoImpl instance) =>
    <String, dynamic>{
      'youtubeUri': instance.youtubeUri,
      'properties': instance.properties?.toJson(),
    };
