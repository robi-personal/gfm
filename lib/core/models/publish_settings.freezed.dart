// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'publish_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PublishState _$PublishStateFromJson(Map<String, dynamic> json) {
  return _PublishState.fromJson(json);
}

/// @nodoc
mixin _$PublishState {
  bool get isPublished => throw _privateConstructorUsedError;
  bool get isAcceptingResponses => throw _privateConstructorUsedError;

  /// Serializes this PublishState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PublishState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PublishStateCopyWith<PublishState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PublishStateCopyWith<$Res> {
  factory $PublishStateCopyWith(
    PublishState value,
    $Res Function(PublishState) then,
  ) = _$PublishStateCopyWithImpl<$Res, PublishState>;
  @useResult
  $Res call({bool isPublished, bool isAcceptingResponses});
}

/// @nodoc
class _$PublishStateCopyWithImpl<$Res, $Val extends PublishState>
    implements $PublishStateCopyWith<$Res> {
  _$PublishStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PublishState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isPublished = null, Object? isAcceptingResponses = null}) {
    return _then(
      _value.copyWith(
            isPublished: null == isPublished
                ? _value.isPublished
                : isPublished // ignore: cast_nullable_to_non_nullable
                      as bool,
            isAcceptingResponses: null == isAcceptingResponses
                ? _value.isAcceptingResponses
                : isAcceptingResponses // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PublishStateImplCopyWith<$Res>
    implements $PublishStateCopyWith<$Res> {
  factory _$$PublishStateImplCopyWith(
    _$PublishStateImpl value,
    $Res Function(_$PublishStateImpl) then,
  ) = __$$PublishStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool isPublished, bool isAcceptingResponses});
}

/// @nodoc
class __$$PublishStateImplCopyWithImpl<$Res>
    extends _$PublishStateCopyWithImpl<$Res, _$PublishStateImpl>
    implements _$$PublishStateImplCopyWith<$Res> {
  __$$PublishStateImplCopyWithImpl(
    _$PublishStateImpl _value,
    $Res Function(_$PublishStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PublishState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? isPublished = null, Object? isAcceptingResponses = null}) {
    return _then(
      _$PublishStateImpl(
        isPublished: null == isPublished
            ? _value.isPublished
            : isPublished // ignore: cast_nullable_to_non_nullable
                  as bool,
        isAcceptingResponses: null == isAcceptingResponses
            ? _value.isAcceptingResponses
            : isAcceptingResponses // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PublishStateImpl implements _PublishState {
  const _$PublishStateImpl({
    this.isPublished = false,
    this.isAcceptingResponses = false,
  });

  factory _$PublishStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PublishStateImplFromJson(json);

  @override
  @JsonKey()
  final bool isPublished;
  @override
  @JsonKey()
  final bool isAcceptingResponses;

  @override
  String toString() {
    return 'PublishState(isPublished: $isPublished, isAcceptingResponses: $isAcceptingResponses)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PublishStateImpl &&
            (identical(other.isPublished, isPublished) ||
                other.isPublished == isPublished) &&
            (identical(other.isAcceptingResponses, isAcceptingResponses) ||
                other.isAcceptingResponses == isAcceptingResponses));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, isPublished, isAcceptingResponses);

  /// Create a copy of PublishState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PublishStateImplCopyWith<_$PublishStateImpl> get copyWith =>
      __$$PublishStateImplCopyWithImpl<_$PublishStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PublishStateImplToJson(this);
  }
}

abstract class _PublishState implements PublishState {
  const factory _PublishState({
    final bool isPublished,
    final bool isAcceptingResponses,
  }) = _$PublishStateImpl;

  factory _PublishState.fromJson(Map<String, dynamic> json) =
      _$PublishStateImpl.fromJson;

  @override
  bool get isPublished;
  @override
  bool get isAcceptingResponses;

  /// Create a copy of PublishState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PublishStateImplCopyWith<_$PublishStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PublishSettings _$PublishSettingsFromJson(Map<String, dynamic> json) {
  return _PublishSettings.fromJson(json);
}

/// @nodoc
mixin _$PublishSettings {
  PublishState get publishState => throw _privateConstructorUsedError;

  /// Serializes this PublishSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PublishSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PublishSettingsCopyWith<PublishSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PublishSettingsCopyWith<$Res> {
  factory $PublishSettingsCopyWith(
    PublishSettings value,
    $Res Function(PublishSettings) then,
  ) = _$PublishSettingsCopyWithImpl<$Res, PublishSettings>;
  @useResult
  $Res call({PublishState publishState});

  $PublishStateCopyWith<$Res> get publishState;
}

/// @nodoc
class _$PublishSettingsCopyWithImpl<$Res, $Val extends PublishSettings>
    implements $PublishSettingsCopyWith<$Res> {
  _$PublishSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PublishSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? publishState = null}) {
    return _then(
      _value.copyWith(
            publishState: null == publishState
                ? _value.publishState
                : publishState // ignore: cast_nullable_to_non_nullable
                      as PublishState,
          )
          as $Val,
    );
  }

  /// Create a copy of PublishSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PublishStateCopyWith<$Res> get publishState {
    return $PublishStateCopyWith<$Res>(_value.publishState, (value) {
      return _then(_value.copyWith(publishState: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PublishSettingsImplCopyWith<$Res>
    implements $PublishSettingsCopyWith<$Res> {
  factory _$$PublishSettingsImplCopyWith(
    _$PublishSettingsImpl value,
    $Res Function(_$PublishSettingsImpl) then,
  ) = __$$PublishSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({PublishState publishState});

  @override
  $PublishStateCopyWith<$Res> get publishState;
}

/// @nodoc
class __$$PublishSettingsImplCopyWithImpl<$Res>
    extends _$PublishSettingsCopyWithImpl<$Res, _$PublishSettingsImpl>
    implements _$$PublishSettingsImplCopyWith<$Res> {
  __$$PublishSettingsImplCopyWithImpl(
    _$PublishSettingsImpl _value,
    $Res Function(_$PublishSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PublishSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? publishState = null}) {
    return _then(
      _$PublishSettingsImpl(
        publishState: null == publishState
            ? _value.publishState
            : publishState // ignore: cast_nullable_to_non_nullable
                  as PublishState,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PublishSettingsImpl implements _PublishSettings {
  const _$PublishSettingsImpl({this.publishState = const PublishState()});

  factory _$PublishSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$PublishSettingsImplFromJson(json);

  @override
  @JsonKey()
  final PublishState publishState;

  @override
  String toString() {
    return 'PublishSettings(publishState: $publishState)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PublishSettingsImpl &&
            (identical(other.publishState, publishState) ||
                other.publishState == publishState));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, publishState);

  /// Create a copy of PublishSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PublishSettingsImplCopyWith<_$PublishSettingsImpl> get copyWith =>
      __$$PublishSettingsImplCopyWithImpl<_$PublishSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PublishSettingsImplToJson(this);
  }
}

abstract class _PublishSettings implements PublishSettings {
  const factory _PublishSettings({final PublishState publishState}) =
      _$PublishSettingsImpl;

  factory _PublishSettings.fromJson(Map<String, dynamic> json) =
      _$PublishSettingsImpl.fromJson;

  @override
  PublishState get publishState;

  /// Create a copy of PublishSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PublishSettingsImplCopyWith<_$PublishSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
