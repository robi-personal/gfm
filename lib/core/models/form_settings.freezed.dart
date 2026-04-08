// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'form_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

QuizSettings _$QuizSettingsFromJson(Map<String, dynamic> json) {
  return _QuizSettings.fromJson(json);
}

/// @nodoc
mixin _$QuizSettings {
  bool get isQuiz => throw _privateConstructorUsedError;

  /// Serializes this QuizSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuizSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuizSettingsCopyWith<QuizSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuizSettingsCopyWith<$Res> {
  factory $QuizSettingsCopyWith(
    QuizSettings value,
    $Res Function(QuizSettings) then,
  ) = _$QuizSettingsCopyWithImpl<$Res, QuizSettings>;
  @useResult
  $Res call({bool isQuiz});
}

/// @nodoc
class _$QuizSettingsCopyWithImpl<$Res, $Val extends QuizSettings>
    implements $QuizSettingsCopyWith<$Res> {
  _$QuizSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuizSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isQuiz = null}) {
    return _then(
      _value.copyWith(
            isQuiz: null == isQuiz
                ? _value.isQuiz
                : isQuiz // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$QuizSettingsImplCopyWith<$Res>
    implements $QuizSettingsCopyWith<$Res> {
  factory _$$QuizSettingsImplCopyWith(
    _$QuizSettingsImpl value,
    $Res Function(_$QuizSettingsImpl) then,
  ) = __$$QuizSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isQuiz});
}

/// @nodoc
class __$$QuizSettingsImplCopyWithImpl<$Res>
    extends _$QuizSettingsCopyWithImpl<$Res, _$QuizSettingsImpl>
    implements _$$QuizSettingsImplCopyWith<$Res> {
  __$$QuizSettingsImplCopyWithImpl(
    _$QuizSettingsImpl _value,
    $Res Function(_$QuizSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of QuizSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isQuiz = null}) {
    return _then(
      _$QuizSettingsImpl(
        isQuiz: null == isQuiz
            ? _value.isQuiz
            : isQuiz // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$QuizSettingsImpl implements _QuizSettings {
  const _$QuizSettingsImpl({this.isQuiz = false});

  factory _$QuizSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuizSettingsImplFromJson(json);

  @override
  @JsonKey()
  final bool isQuiz;

  @override
  String toString() {
    return 'QuizSettings(isQuiz: $isQuiz)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuizSettingsImpl &&
            (identical(other.isQuiz, isQuiz) || other.isQuiz == isQuiz));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, isQuiz);

  /// Create a copy of QuizSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuizSettingsImplCopyWith<_$QuizSettingsImpl> get copyWith =>
      __$$QuizSettingsImplCopyWithImpl<_$QuizSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuizSettingsImplToJson(this);
  }
}

abstract class _QuizSettings implements QuizSettings {
  const factory _QuizSettings({final bool isQuiz}) = _$QuizSettingsImpl;

  factory _QuizSettings.fromJson(Map<String, dynamic> json) =
      _$QuizSettingsImpl.fromJson;

  @override
  bool get isQuiz;

  /// Create a copy of QuizSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuizSettingsImplCopyWith<_$QuizSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FormSettings _$FormSettingsFromJson(Map<String, dynamic> json) {
  return _FormSettings.fromJson(json);
}

/// @nodoc
mixin _$FormSettings {
  QuizSettings get quizSettings => throw _privateConstructorUsedError;
  @_EmailCollectionTypeConverter()
  EmailCollectionType get emailCollectionType =>
      throw _privateConstructorUsedError;

  /// Serializes this FormSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FormSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FormSettingsCopyWith<FormSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FormSettingsCopyWith<$Res> {
  factory $FormSettingsCopyWith(
    FormSettings value,
    $Res Function(FormSettings) then,
  ) = _$FormSettingsCopyWithImpl<$Res, FormSettings>;
  @useResult
  $Res call({
    QuizSettings quizSettings,
    @_EmailCollectionTypeConverter() EmailCollectionType emailCollectionType,
  });

  $QuizSettingsCopyWith<$Res> get quizSettings;
}

/// @nodoc
class _$FormSettingsCopyWithImpl<$Res, $Val extends FormSettings>
    implements $FormSettingsCopyWith<$Res> {
  _$FormSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FormSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? quizSettings = null, Object? emailCollectionType = null}) {
    return _then(
      _value.copyWith(
            quizSettings: null == quizSettings
                ? _value.quizSettings
                : quizSettings // ignore: cast_nullable_to_non_nullable
                      as QuizSettings,
            emailCollectionType: null == emailCollectionType
                ? _value.emailCollectionType
                : emailCollectionType // ignore: cast_nullable_to_non_nullable
                      as EmailCollectionType,
          )
          as $Val,
    );
  }

  /// Create a copy of FormSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuizSettingsCopyWith<$Res> get quizSettings {
    return $QuizSettingsCopyWith<$Res>(_value.quizSettings, (value) {
      return _then(_value.copyWith(quizSettings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FormSettingsImplCopyWith<$Res>
    implements $FormSettingsCopyWith<$Res> {
  factory _$$FormSettingsImplCopyWith(
    _$FormSettingsImpl value,
    $Res Function(_$FormSettingsImpl) then,
  ) = __$$FormSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    QuizSettings quizSettings,
    @_EmailCollectionTypeConverter() EmailCollectionType emailCollectionType,
  });

  @override
  $QuizSettingsCopyWith<$Res> get quizSettings;
}

/// @nodoc
class __$$FormSettingsImplCopyWithImpl<$Res>
    extends _$FormSettingsCopyWithImpl<$Res, _$FormSettingsImpl>
    implements _$$FormSettingsImplCopyWith<$Res> {
  __$$FormSettingsImplCopyWithImpl(
    _$FormSettingsImpl _value,
    $Res Function(_$FormSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FormSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? quizSettings = null, Object? emailCollectionType = null}) {
    return _then(
      _$FormSettingsImpl(
        quizSettings: null == quizSettings
            ? _value.quizSettings
            : quizSettings // ignore: cast_nullable_to_non_nullable
                  as QuizSettings,
        emailCollectionType: null == emailCollectionType
            ? _value.emailCollectionType
            : emailCollectionType // ignore: cast_nullable_to_non_nullable
                  as EmailCollectionType,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FormSettingsImpl extends _FormSettings {
  const _$FormSettingsImpl({
    this.quizSettings = const QuizSettings(),
    @_EmailCollectionTypeConverter()
    this.emailCollectionType = EmailCollectionType.doNotCollect,
  }) : super._();

  factory _$FormSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$FormSettingsImplFromJson(json);

  @override
  @JsonKey()
  final QuizSettings quizSettings;
  @override
  @JsonKey()
  @_EmailCollectionTypeConverter()
  final EmailCollectionType emailCollectionType;

  @override
  String toString() {
    return 'FormSettings(quizSettings: $quizSettings, emailCollectionType: $emailCollectionType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FormSettingsImpl &&
            (identical(other.quizSettings, quizSettings) ||
                other.quizSettings == quizSettings) &&
            (identical(other.emailCollectionType, emailCollectionType) ||
                other.emailCollectionType == emailCollectionType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, quizSettings, emailCollectionType);

  /// Create a copy of FormSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FormSettingsImplCopyWith<_$FormSettingsImpl> get copyWith =>
      __$$FormSettingsImplCopyWithImpl<_$FormSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FormSettingsImplToJson(this);
  }
}

abstract class _FormSettings extends FormSettings {
  const factory _FormSettings({
    final QuizSettings quizSettings,
    @_EmailCollectionTypeConverter()
    final EmailCollectionType emailCollectionType,
  }) = _$FormSettingsImpl;
  const _FormSettings._() : super._();

  factory _FormSettings.fromJson(Map<String, dynamic> json) =
      _$FormSettingsImpl.fromJson;

  @override
  QuizSettings get quizSettings;
  @override
  @_EmailCollectionTypeConverter()
  EmailCollectionType get emailCollectionType;

  /// Create a copy of FormSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FormSettingsImplCopyWith<_$FormSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
