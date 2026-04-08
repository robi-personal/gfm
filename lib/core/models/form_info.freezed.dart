// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'form_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FormInfo _$FormInfoFromJson(Map<String, dynamic> json) {
  return _FormInfo.fromJson(json);
}

/// @nodoc
mixin _$FormInfo {
  String get title => throw _privateConstructorUsedError;
  String get documentTitle => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Serializes this FormInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FormInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FormInfoCopyWith<FormInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FormInfoCopyWith<$Res> {
  factory $FormInfoCopyWith(FormInfo value, $Res Function(FormInfo) then) =
      _$FormInfoCopyWithImpl<$Res, FormInfo>;
  @useResult
  $Res call({String title, String documentTitle, String description});
}

/// @nodoc
class _$FormInfoCopyWithImpl<$Res, $Val extends FormInfo>
    implements $FormInfoCopyWith<$Res> {
  _$FormInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FormInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? documentTitle = null,
    Object? description = null,
  }) {
    return _then(
      _value.copyWith(
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            documentTitle: null == documentTitle
                ? _value.documentTitle
                : documentTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FormInfoImplCopyWith<$Res>
    implements $FormInfoCopyWith<$Res> {
  factory _$$FormInfoImplCopyWith(
    _$FormInfoImpl value,
    $Res Function(_$FormInfoImpl) then,
  ) = __$$FormInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String title, String documentTitle, String description});
}

/// @nodoc
class __$$FormInfoImplCopyWithImpl<$Res>
    extends _$FormInfoCopyWithImpl<$Res, _$FormInfoImpl>
    implements _$$FormInfoImplCopyWith<$Res> {
  __$$FormInfoImplCopyWithImpl(
    _$FormInfoImpl _value,
    $Res Function(_$FormInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FormInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? title = null,
    Object? documentTitle = null,
    Object? description = null,
  }) {
    return _then(
      _$FormInfoImpl(
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        documentTitle: null == documentTitle
            ? _value.documentTitle
            : documentTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FormInfoImpl implements _FormInfo {
  const _$FormInfoImpl({
    required this.title,
    required this.documentTitle,
    this.description = '',
  });

  factory _$FormInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$FormInfoImplFromJson(json);

  @override
  final String title;
  @override
  final String documentTitle;
  @override
  @JsonKey()
  final String description;

  @override
  String toString() {
    return 'FormInfo(title: $title, documentTitle: $documentTitle, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FormInfoImpl &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.documentTitle, documentTitle) ||
                other.documentTitle == documentTitle) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, title, documentTitle, description);

  /// Create a copy of FormInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FormInfoImplCopyWith<_$FormInfoImpl> get copyWith =>
      __$$FormInfoImplCopyWithImpl<_$FormInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FormInfoImplToJson(this);
  }
}

abstract class _FormInfo implements FormInfo {
  const factory _FormInfo({
    required final String title,
    required final String documentTitle,
    final String description,
  }) = _$FormInfoImpl;

  factory _FormInfo.fromJson(Map<String, dynamic> json) =
      _$FormInfoImpl.fromJson;

  @override
  String get title;
  @override
  String get documentTitle;
  @override
  String get description;

  /// Create a copy of FormInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FormInfoImplCopyWith<_$FormInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
