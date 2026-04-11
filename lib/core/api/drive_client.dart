import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart';

import '../auth/google_auth_datasource.dart';

/// Lazy singleton wrapper around [DriveApi]. The API instance is built on
/// first access, using the authenticated client from [GoogleAuthDataSource].
class DriveClient {
  final GoogleAuthDataSource _authService;
  DriveApi? _api;

  DriveClient(this._authService);

  DriveApi get api {
    _api ??= DriveApi(_authService.buildAuthClient());
    return _api!;
  }

  /// Call after sign-out to force a fresh client on next sign-in.
  void reset() => _api = null;

  /// Uploads [bytes] to Drive, sets it public (anyone with link can view),
  /// and returns a publicly accessible URL for use as a Forms image source.
  Future<String> uploadImage(Uint8List bytes, String mimeType) async {
    final metadata = File()
      ..name = 'form_image_${DateTime.now().millisecondsSinceEpoch}'
      ..mimeType = mimeType;

    final media = Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );

    final created = await api.files.create(metadata, uploadMedia: media);
    final fileId = created.id!;

    await api.permissions.create(
      Permission()
        ..type = 'anyone'
        ..role = 'reader',
      fileId,
    );

    return 'https://drive.google.com/uc?id=$fileId&export=view';
  }
}
