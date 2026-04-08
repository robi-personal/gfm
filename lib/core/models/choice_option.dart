import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'form_image.dart';

part 'choice_option.freezed.dart';
part 'choice_option.g.dart';

/// A single option inside a [ChoiceQuestion].
/// Either [goToAction] or [goToSectionId] may be set for branching — not both.
@freezed
class ChoiceOption with _$ChoiceOption {
  const ChoiceOption._();

  const factory ChoiceOption({
    required String value,
    FormImage? image,
    @Default(false) bool isOther,
    @_GoToActionConverter() GoToAction? goToAction,
    String? goToSectionId,
  }) = _ChoiceOption;

  factory ChoiceOption.fromJson(Map<String, dynamic> json) =>
      _$ChoiceOptionFromJson(json);
}

class _GoToActionConverter implements JsonConverter<GoToAction?, String?> {
  const _GoToActionConverter();

  @override
  GoToAction? fromJson(String? json) =>
      json == null ? null : GoToAction.fromJson(json);

  @override
  String? toJson(GoToAction? object) => object?.toJson();
}
