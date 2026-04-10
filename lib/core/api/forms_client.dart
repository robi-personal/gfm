import 'package:googleapis/forms/v1.dart';

import '../auth/google_auth_datasource.dart';

/// Lazy singleton wrapper around [FormsApi]. The API instance is built on
/// first access, using the authenticated client from [GoogleAuthDataSource].
class FormsClient {
  final GoogleAuthDataSource _authService;
  FormsApi? _api;

  FormsClient(this._authService);

  FormsApi get api {
    _api ??= FormsApi(_authService.buildAuthClient());
    return _api!;
  }

  /// Call after sign-out to force a fresh client on next sign-in.
  void reset() => _api = null;
}
