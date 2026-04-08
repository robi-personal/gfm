// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'form_image.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FormImage _$FormImageFromJson(Map<String, dynamic> json) {
  return _FormImage.fromJson(json);
}

/// @nodoc
mixin _$FormImage {
  String? get contentUri => throw _privateConstructorUsedError;
  String? get sourceUri => throw _privateConstructorUsedError;
  String? get altText => throw _privateConstructorUsedError;
  MediaProperties? get properties => throw _privateConstructorUsedError;

  /// Serializes this FormImage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FormImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FormImageCopyWith<FormImage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FormImageCopyWith<$Res> {
  factory $FormImageCopyWith(FormImage value, $Res Function(FormImage) then) =
      _$FormImageCopyWithImpl<$Res, FormImage>;
  @useResult
  $Res call({
    String? contentUri,
    String? sourceUri,
    String? altText,
    MediaProperties? properties,
  });

  $MediaPropertiesCopyWith<$Res>? get properties;
}

/// @nodoc
class _$FormImageCopyWithImpl<$Res, $Val extends FormImage>
    implements $FormImageCopyWith<$Res> {
  _$FormImageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FormImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentUri = freezed,
    Object? sourceUri = freezed,
    Object? altText = freezed,
    Object? properties = freezed,
  }) {
    return _then(
      _value.copyWith(
            contentUri: freezed == contentUri
                ? _value.contentUri
                : contentUri // ignore: cast_nullable_to_non_nullable
                      as String?,
            sourceUri: freezed == sourceUri
                ? _value.sourceUri
                : sourceUri // ignore: cast_nullable_to_non_nullable
                      as String?,
            altText: freezed == altText
                ? _value.altText
                : altText // ignore: cast_nullable_to_non_nullable
                      as String?,
            properties: freezed == properties
                ? _value.properties
                : properties // ignore: cast_nullable_to_non_nullable
                      as MediaProperties?,
          )
          as $Val,
    );
  }

  /// Create a copy of FormImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MediaPropertiesCopyWith<$Res>? get properties {
    if (_value.properties == null) {
      return null;
    }

    return $MediaPropertiesCopyWith<$Res>(_value.properties!, (value) {
      return _then(_value.copyWith(properties: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FormImageImplCopyWith<$Res>
    implements $FormImageCopyWith<$Res> {
  factory _$$FormImageImplCopyWith(
    _$FormImageImpl value,
    $Res Function(_$FormImageImpl) then,
  ) = __$$FormImageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? contentUri,
    String? sourceUri,
    String? altText,
    MediaProperties? properties,
  });

  @override
  $MediaPropertiesCopyWith<$Res>? get properties;
}

/// @nodoc
class __$$FormImageImplCopyWithImpl<$Res>
    extends _$FormImageCopyWithImpl<$Res, _$FormImageImpl>
    implements _$$FormImageImplCopyWith<$Res> {
  __$$FormImageImplCopyWithImpl(
    _$FormImageImpl _value,
    $Res Function(_$FormImageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FormImage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentUri = freezed,
    Object? sourceUri = freezed,
    Object? altText = freezed,
    Object? properties = freezed,
  }) {
    return _then(
      _$FormImageImpl(
        contentUri: freezed == contentUri
            ? _value.contentUri
            : contentUri // ignore: cast_nullable_to_non_nullable
                  as String?,
        sourceUri: freezed == sourceUri
            ? _value.sourceUri
            : sourceUri // ignore: cast_nullable_to_non_nullable
                  as String?,
        altText: freezed == altText
            ? _value.altText
            : altText // ignore: cast_nullable_to_non_nullable
                  as String?,
        properties: freezed == properties
            ? _value.properties
            : properties // ignore: cast_nullable_to_non_nullable
                  as MediaProperties?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FormImageImpl implements _FormImage {
  const _$FormImageImpl({
    this.contentUri,
    this.sourceUri,
    this.altText,
    this.properties,
  });

  factory _$FormImageImpl.fromJson(Map<String, dynamic> json) =>
      _$$FormImageImplFromJson(json);

  @override
  final String? contentUri;
  @override
  final String? sourceUri;
  @override
  final String? altText;
  @override
  final MediaProperties? properties;

  @override
  String toString() {
    return 'FormImage(contentUri: $contentUri, sourceUri: $sourceUri, altText: $altText, properties: $properties)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FormImageImpl &&
            (identical(other.contentUri, contentUri) ||
                other.contentUri == contentUri) &&
            (identical(other.sourceUri, sourceUri) ||
                other.sourceUri == sourceUri) &&
            (identical(other.altText, altText) || other.altText == altText) &&
            (identical(other.properties, properties) ||
                other.properties == properties));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, contentUri, sourceUri, altText, properties);

  /// Create a copy of FormImage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FormImageImplCopyWith<_$FormImageImpl> get copyWith =>
      __$$FormImageImplCopyWithImpl<_$FormImageImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FormImageImplToJson(this);
  }
}

abstract class _FormImage implements FormImage {
  const factory _FormImage({
    final String? contentUri,
    final String? sourceUri,
    final String? altText,
    final MediaProperties? properties,
  }) = _$FormImageImpl;

  factory _FormImage.fromJson(Map<String, dynamic> json) =
      _$FormImageImpl.fromJson;

  @override
  String? get contentUri;
  @override
  String? get sourceUri;
  @override
  String? get altText;
  @override
  MediaProperties? get properties;

  /// Create a copy of FormImage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FormImageImplCopyWith<_$FormImageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MediaProperties _$MediaPropertiesFromJson(Map<String, dynamic> json) {
  return _MediaProperties.fromJson(json);
}

/// @nodoc
mixin _$MediaProperties {
  String? get alignment => throw _privateConstructorUsedError;
  int? get width => throw _privateConstructorUsedError;

  /// Serializes this MediaProperties to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MediaProperties
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MediaPropertiesCopyWith<MediaProperties> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MediaPropertiesCopyWith<$Res> {
  factory $MediaPropertiesCopyWith(
    MediaProperties value,
    $Res Function(MediaProperties) then,
  ) = _$MediaPropertiesCopyWithImpl<$Res, MediaProperties>;
  @useResult
  $Res call({String? alignment, int? width});
}

/// @nodoc
class _$MediaPropertiesCopyWithImpl<$Res, $Val extends MediaProperties>
    implements $MediaPropertiesCopyWith<$Res> {
  _$MediaPropertiesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MediaProperties
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? alignment = freezed, Object? width = freezed}) {
    return _then(
      _value.copyWith(
            alignment: freezed == alignment
                ? _value.alignment
                : alignment // ignore: cast_nullable_to_non_nullable
                      as String?,
            width: freezed == width
                ? _value.width
                : width // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MediaPropertiesImplCopyWith<$Res>
    implements $MediaPropertiesCopyWith<$Res> {
  factory _$$MediaPropertiesImplCopyWith(
    _$MediaPropertiesImpl value,
    $Res Function(_$MediaPropertiesImpl) then,
  ) = __$$MediaPropertiesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? alignment, int? width});
}

/// @nodoc
class __$$MediaPropertiesImplCopyWithImpl<$Res>
    extends _$MediaPropertiesCopyWithImpl<$Res, _$MediaPropertiesImpl>
    implements _$$MediaPropertiesImplCopyWith<$Res> {
  __$$MediaPropertiesImplCopyWithImpl(
    _$MediaPropertiesImpl _value,
    $Res Function(_$MediaPropertiesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MediaProperties
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? alignment = freezed, Object? width = freezed}) {
    return _then(
      _$MediaPropertiesImpl(
        alignment: freezed == alignment
            ? _value.alignment
            : alignment // ignore: cast_nullable_to_non_nullable
                  as String?,
        width: freezed == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MediaPropertiesImpl implements _MediaProperties {
  const _$MediaPropertiesImpl({this.alignment, this.width});

  factory _$MediaPropertiesImpl.fromJson(Map<String, dynamic> json) =>
      _$$MediaPropertiesImplFromJson(json);

  @override
  final String? alignment;
  @override
  final int? width;

  @override
  String toString() {
    return 'MediaProperties(alignment: $alignment, width: $width)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MediaPropertiesImpl &&
            (identical(other.alignment, alignment) ||
                other.alignment == alignment) &&
            (identical(other.width, width) || other.width == width));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, alignment, width);

  /// Create a copy of MediaProperties
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MediaPropertiesImplCopyWith<_$MediaPropertiesImpl> get copyWith =>
      __$$MediaPropertiesImplCopyWithImpl<_$MediaPropertiesImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MediaPropertiesImplToJson(this);
  }
}

abstract class _MediaProperties implements MediaProperties {
  const factory _MediaProperties({final String? alignment, final int? width}) =
      _$MediaPropertiesImpl;

  factory _MediaProperties.fromJson(Map<String, dynamic> json) =
      _$MediaPropertiesImpl.fromJson;

  @override
  String? get alignment;
  @override
  int? get width;

  /// Create a copy of MediaProperties
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MediaPropertiesImplCopyWith<_$MediaPropertiesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FormVideo _$FormVideoFromJson(Map<String, dynamic> json) {
  return _FormVideo.fromJson(json);
}

/// @nodoc
mixin _$FormVideo {
  String get youtubeUri => throw _privateConstructorUsedError;
  MediaProperties? get properties => throw _privateConstructorUsedError;

  /// Serializes this FormVideo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FormVideo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FormVideoCopyWith<FormVideo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FormVideoCopyWith<$Res> {
  factory $FormVideoCopyWith(FormVideo value, $Res Function(FormVideo) then) =
      _$FormVideoCopyWithImpl<$Res, FormVideo>;
  @useResult
  $Res call({String youtubeUri, MediaProperties? properties});

  $MediaPropertiesCopyWith<$Res>? get properties;
}

/// @nodoc
class _$FormVideoCopyWithImpl<$Res, $Val extends FormVideo>
    implements $FormVideoCopyWith<$Res> {
  _$FormVideoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FormVideo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? youtubeUri = null, Object? properties = freezed}) {
    return _then(
      _value.copyWith(
            youtubeUri: null == youtubeUri
                ? _value.youtubeUri
                : youtubeUri // ignore: cast_nullable_to_non_nullable
                      as String,
            properties: freezed == properties
                ? _value.properties
                : properties // ignore: cast_nullable_to_non_nullable
                      as MediaProperties?,
          )
          as $Val,
    );
  }

  /// Create a copy of FormVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MediaPropertiesCopyWith<$Res>? get properties {
    if (_value.properties == null) {
      return null;
    }

    return $MediaPropertiesCopyWith<$Res>(_value.properties!, (value) {
      return _then(_value.copyWith(properties: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FormVideoImplCopyWith<$Res>
    implements $FormVideoCopyWith<$Res> {
  factory _$$FormVideoImplCopyWith(
    _$FormVideoImpl value,
    $Res Function(_$FormVideoImpl) then,
  ) = __$$FormVideoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String youtubeUri, MediaProperties? properties});

  @override
  $MediaPropertiesCopyWith<$Res>? get properties;
}

/// @nodoc
class __$$FormVideoImplCopyWithImpl<$Res>
    extends _$FormVideoCopyWithImpl<$Res, _$FormVideoImpl>
    implements _$$FormVideoImplCopyWith<$Res> {
  __$$FormVideoImplCopyWithImpl(
    _$FormVideoImpl _value,
    $Res Function(_$FormVideoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FormVideo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? youtubeUri = null, Object? properties = freezed}) {
    return _then(
      _$FormVideoImpl(
        youtubeUri: null == youtubeUri
            ? _value.youtubeUri
            : youtubeUri // ignore: cast_nullable_to_non_nullable
                  as String,
        properties: freezed == properties
            ? _value.properties
            : properties // ignore: cast_nullable_to_non_nullable
                  as MediaProperties?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FormVideoImpl implements _FormVideo {
  const _$FormVideoImpl({required this.youtubeUri, this.properties});

  factory _$FormVideoImpl.fromJson(Map<String, dynamic> json) =>
      _$$FormVideoImplFromJson(json);

  @override
  final String youtubeUri;
  @override
  final MediaProperties? properties;

  @override
  String toString() {
    return 'FormVideo(youtubeUri: $youtubeUri, properties: $properties)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FormVideoImpl &&
            (identical(other.youtubeUri, youtubeUri) ||
                other.youtubeUri == youtubeUri) &&
            (identical(other.properties, properties) ||
                other.properties == properties));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, youtubeUri, properties);

  /// Create a copy of FormVideo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FormVideoImplCopyWith<_$FormVideoImpl> get copyWith =>
      __$$FormVideoImplCopyWithImpl<_$FormVideoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FormVideoImplToJson(this);
  }
}

abstract class _FormVideo implements FormVideo {
  const factory _FormVideo({
    required final String youtubeUri,
    final MediaProperties? properties,
  }) = _$FormVideoImpl;

  factory _FormVideo.fromJson(Map<String, dynamic> json) =
      _$FormVideoImpl.fromJson;

  @override
  String get youtubeUri;
  @override
  MediaProperties? get properties;

  /// Create a copy of FormVideo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FormVideoImplCopyWith<_$FormVideoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
