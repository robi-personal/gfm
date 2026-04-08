part of 'auth_cubit.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedIn extends AuthState {
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AuthSignedIn({
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignInFailed extends AuthState {
  final String message;
  const AuthSignInFailed(this.message);
}
