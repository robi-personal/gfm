import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_image.freezed.dart';
part 'form_image.g.dart';

/// Represents an image embedded in a form item or question option.
/// [sourceUri] must be a publicly accessible URL.
@freezed
class FormImage with _$FormImage {
  const factory FormImage({
    String? contentUri,
    String? sourceUri,
    String? altText,
    MediaProperties? properties,
  }) = _FormImage;

  factory FormImage.fromJson(Map<String, dynamic> json) =>
      _$FormImageFromJson(json);
}

@freezed
class MediaProperties with _$MediaProperties {
  const factory MediaProperties({
    String? alignment,
    int? width,
  }) = _MediaProperties;

  factory MediaProperties.fromJson(Map<String, dynamic> json) =>
      _$MediaPropertiesFromJson(json);
}

/// Represents a YouTube video embedded in a form item.
@freezed
class FormVideo with _$FormVideo {
  const factory FormVideo({
    required String youtubeUri,
    MediaProperties? properties,
  }) = _FormVideo;

  factory FormVideo.fromJson(Map<String, dynamic> json) =>
      _$FormVideoFromJson(json);
}
