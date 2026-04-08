// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'choice_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChoiceOptionImpl _$$ChoiceOptionImplFromJson(Map<String, dynamic> json) =>
    _$ChoiceOptionImpl(
      value: json['value'] as String,
      image: json['image'] == null
          ? null
          : FormImage.fromJson(json['image'] as Map<String, dynamic>),
      isOther: json['isOther'] as bool? ?? false,
      goToAction: const _GoToActionConverter().fromJson(
        json['goToAction'] as String?,
      ),
      goToSectionId: json['goToSectionId'] as String?,
    );

Map<String, dynamic> _$$ChoiceOptionImplToJson(_$ChoiceOptionImpl instance) =>
    <String, dynamic>{
      'value': instance.value,
      'image': instance.image?.toJson(),
      'isOther': instance.isOther,
      'goToAction': const _GoToActionConverter().toJson(instance.goToAction),
      'goToSectionId': instance.goToSectionId,
    };
