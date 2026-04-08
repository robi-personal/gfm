// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'choice_option.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChoiceOption _$ChoiceOptionFromJson(Map<String, dynamic> json) {
  return _ChoiceOption.fromJson(json);
}

/// @nodoc
mixin _$ChoiceOption {
  String get value => throw _privateConstructorUsedError;
  FormImage? get image => throw _privateConstructorUsedError;
  bool get isOther => throw _privateConstructorUsedError;
  @_GoToActionConverter()
  GoToAction? get goToAction => throw _privateConstructorUsedError;
  String? get goToSectionId => throw _privateConstructorUsedError;

  /// Serializes this ChoiceOption to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChoiceOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChoiceOptionCopyWith<ChoiceOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChoiceOptionCopyWith<$Res> {
  factory $ChoiceOptionCopyWith(
    ChoiceOption value,
    $Res Function(ChoiceOption) then,
  ) = _$ChoiceOptionCopyWithImpl<$Res, ChoiceOption>;
  @useResult
  $Res call({
    String value,
    FormImage? image,
    bool isOther,
    @_GoToActionConverter() GoToAction? goToAction,
    String? goToSectionId,
  });

  $FormImageCopyWith<$Res>? get image;
}

/// @nodoc
class _$ChoiceOptionCopyWithImpl<$Res, $Val extends ChoiceOption>
    implements $ChoiceOptionCopyWith<$Res> {
  _$ChoiceOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChoiceOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? image = freezed,
    Object? isOther = null,
    Object? goToAction = freezed,
    Object? goToSectionId = freezed,
  }) {
    return _then(
      _value.copyWith(
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String,
            image: freezed == image
                ? _value.image
                : image // ignore: cast_nullable_to_non_nullable
                      as FormImage?,
            isOther: null == isOther
                ? _value.isOther
                : isOther // ignore: cast_nullable_to_non_nullable
                      as bool,
            goToAction: freezed == goToAction
                ? _value.goToAction
                : goToAction // ignore: cast_nullable_to_non_nullable
                      as GoToAction?,
            goToSectionId: freezed == goToSectionId
                ? _value.goToSectionId
                : goToSectionId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of ChoiceOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FormImageCopyWith<$Res>? get image {
    if (_value.image == null) {
      return null;
    }

    return $FormImageCopyWith<$Res>(_value.image!, (value) {
      return _then(_value.copyWith(image: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ChoiceOptionImplCopyWith<$Res>
    implements $ChoiceOptionCopyWith<$Res> {
  factory _$$ChoiceOptionImplCopyWith(
    _$ChoiceOptionImpl value,
    $Res Function(_$ChoiceOptionImpl) then,
  ) = __$$ChoiceOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String value,
    FormImage? image,
    bool isOther,
    @_GoToActionConverter() GoToAction? goToAction,
    String? goToSectionId,
  });

  @override
  $FormImageCopyWith<$Res>? get image;
}

/// @nodoc
class __$$ChoiceOptionImplCopyWithImpl<$Res>
    extends _$ChoiceOptionCopyWithImpl<$Res, _$ChoiceOptionImpl>
    implements _$$ChoiceOptionImplCopyWith<$Res> {
  __$$ChoiceOptionImplCopyWithImpl(
    _$ChoiceOptionImpl _value,
    $Res Function(_$ChoiceOptionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChoiceOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
    Object? image = freezed,
    Object? isOther = null,
    Object? goToAction = freezed,
    Object? goToSectionId = freezed,
  }) {
    return _then(
      _$ChoiceOptionImpl(
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        image: freezed == image
            ? _value.image
            : image // ignore: cast_nullable_to_non_nullable
                  as FormImage?,
        isOther: null == isOther
            ? _value.isOther
            : isOther // ignore: cast_nullable_to_non_nullable
                  as bool,
        goToAction: freezed == goToAction
            ? _value.goToAction
            : goToAction // ignore: cast_nullable_to_non_nullable
                  as GoToAction?,
        goToSectionId: freezed == goToSectionId
            ? _value.goToSectionId
            : goToSectionId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChoiceOptionImpl extends _ChoiceOption {
  const _$ChoiceOptionImpl({
    required this.value,
    this.image,
    this.isOther = false,
    @_GoToActionConverter() this.goToAction,
    this.goToSectionId,
  }) : super._();

  factory _$ChoiceOptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChoiceOptionImplFromJson(json);

  @override
  final String value;
  @override
  final FormImage? image;
  @override
  @JsonKey()
  final bool isOther;
  @override
  @_GoToActionConverter()
  final GoToAction? goToAction;
  @override
  final String? goToSectionId;

  @override
  String toString() {
    return 'ChoiceOption(value: $value, image: $image, isOther: $isOther, goToAction: $goToAction, goToSectionId: $goToSectionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChoiceOptionImpl &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.isOther, isOther) || other.isOther == isOther) &&
            (identical(other.goToAction, goToAction) ||
                other.goToAction == goToAction) &&
            (identical(other.goToSectionId, goToSectionId) ||
                other.goToSectionId == goToSectionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    value,
    image,
    isOther,
    goToAction,
    goToSectionId,
  );

  /// Create a copy of ChoiceOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChoiceOptionImplCopyWith<_$ChoiceOptionImpl> get copyWith =>
      __$$ChoiceOptionImplCopyWithImpl<_$ChoiceOptionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChoiceOptionImplToJson(this);
  }
}

abstract class _ChoiceOption extends ChoiceOption {
  const factory _ChoiceOption({
    required final String value,
    final FormImage? image,
    final bool isOther,
    @_GoToActionConverter() final GoToAction? goToAction,
    final String? goToSectionId,
  }) = _$ChoiceOptionImpl;
  const _ChoiceOption._() : super._();

  factory _ChoiceOption.fromJson(Map<String, dynamic> json) =
      _$ChoiceOptionImpl.fromJson;

  @override
  String get value;
  @override
  FormImage? get image;
  @override
  bool get isOther;
  @override
  @_GoToActionConverter()
  GoToAction? get goToAction;
  @override
  String? get goToSectionId;

  /// Create a copy of ChoiceOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChoiceOptionImplCopyWith<_$ChoiceOptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
