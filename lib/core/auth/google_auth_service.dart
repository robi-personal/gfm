import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'auth_failure.dart';

class GoogleAuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/forms.body',
    'https://www.googleapis.com/auth/forms.responses.readonly',
  ];

  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  bool get isSignedIn => _googleSignIn.currentUser != null;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Attempts a silent sign-in on app launch. Returns [SignInCancelled] if
  /// the user has no cached session and must sign in interactively.
  Future<Either<AuthFailure, void>> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return const Left(SignInCancelled());
      return const Right(null);
    } catch (e) {
      return Left(SignInFailed(e.toString()));
    }
  }

  /// Interactive Google Sign-In. Returns [SignInCancelled] if the user
  /// dismisses the picker.
  Future<Either<AuthFailure, void>> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return const Left(SignInCancelled());
      return const Right(null);
    } catch (e) {
      return Left(SignInFailed(e.toString()));
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Returns an [http.Client] whose every request is signed with the current
  /// user's OAuth token. The client re-fetches the token on each request via
  /// [GoogleSignInAccount.authHeaders], so token refresh is handled
  /// automatically by the google_sign_in plugin — never manually here.
  http.Client buildAuthClient() {
    return _GoogleAuthClient(_googleSignIn);
  }
}

/// An [http.BaseClient] that injects OAuth2 `Authorization` headers obtained
/// from [GoogleSignIn.currentUser.authHeaders]. The plugin refreshes the
/// access token before expiry transparently.
class _GoogleAuthClient extends http.BaseClient {
  final GoogleSignIn _googleSignIn;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._googleSignIn);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final user = _googleSignIn.currentUser;
    if (user == null) throw StateError('Not signed in');
    final headers = await user.authHeaders;
    request.headers.addAll(headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
