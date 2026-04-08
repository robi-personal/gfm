// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FormInfoImpl _$$FormInfoImplFromJson(Map<String, dynamic> json) =>
    _$FormInfoImpl(
      title: json['title'] as String,
      documentTitle: json['documentTitle'] as String,
      description: json['description'] as String? ?? '',
    );

Map<String, dynamic> _$$FormInfoImplToJson(_$FormInfoImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'documentTitle': instance.documentTitle,
      'description': instance.description,
    };
