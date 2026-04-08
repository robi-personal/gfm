import 'package:bloc/bloc.dart';

import '../api/drive_client.dart';
import '../api/forms_client.dart';
import 'auth_failure.dart';
import 'google_auth_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final GoogleAuthService _authService;
  final FormsClient _formsClient;
  final DriveClient _driveClient;

  AuthCubit(this._authService, this._formsClient, this._driveClient)
      : super(const AuthInitial());

  /// Called on app launch. Tries silent sign-in from cached credentials.
  Future<void> checkAuth() async {
    emit(const AuthLoading());
    final result = await _authService.signInSilently();
    result.fold(
      (_) => emit(const AuthSignedOut()),
      (_) => _emitSignedIn(),
    );
  }

  /// Interactive sign-in triggered by the user tapping the button.
  Future<void> signIn() async {
    emit(const AuthLoading());
    final result = await _authService.signIn();
    result.fold(
      (failure) => switch (failure) {
        SignInCancelled() => emit(const AuthSignedOut()),
        SignInFailed(:final message) => emit(AuthSignInFailed(message)),
        TokenExpired() => emit(const AuthSignedOut()),
      },
      (_) => _emitSignedIn(),
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _formsClient.reset();
    _driveClient.reset();
    emit(const AuthSignedOut());
  }

  void _emitSignedIn() {
    final user = _authService.currentUser!;
    emit(AuthSignedIn(
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
    ));
  }
}
