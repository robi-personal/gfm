import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../error/failure.dart';

/// Raw data source for Google authentication.
/// Returns [GoogleSignInAccount] on success so the repository can map it
/// to the domain [AuthUser] entity. Maps exceptions to [Failure] types.
class GoogleAuthDataSource {
  static const _scopes = [
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/forms.body',
    'https://www.googleapis.com/auth/forms.responses.readonly',
  ];

  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  bool get isSignedIn => _googleSignIn.currentUser != null;

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<Either<Failure, GoogleSignInAccount>> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return const Left(AuthCancelledFailure());
      return Right(account);
    } on SocketException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  Future<Either<Failure, GoogleSignInAccount>> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return const Left(AuthCancelledFailure());
      return Right(account);
    } on SocketException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  /// Returns an [http.Client] whose every request is signed with the current
  /// user's OAuth token. Token refresh is handled automatically by the plugin.
  http.Client buildAuthClient() => _GoogleAuthClient(_googleSignIn);
}

/// Injects OAuth2 `Authorization` headers on every request.
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
