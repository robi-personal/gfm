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
}
