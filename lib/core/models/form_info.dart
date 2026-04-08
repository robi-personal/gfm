import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_info.freezed.dart';
part 'form_info.g.dart';

@freezed
class FormInfo with _$FormInfo {
  const factory FormInfo({
    required String title,
    required String documentTitle,
    @Default('') String description,
  }) = _FormInfo;

  factory FormInfo.fromJson(Map<String, dynamic> json) =>
      _$FormInfoFromJson(json);
}
