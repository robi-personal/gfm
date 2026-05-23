part of 'sign_in_cubit.dart';

sealed class SignInState {
  const SignInState();
}

/// Before [SignInCubit.checkAuth] completes — shows splash screen.
class SignInInitial extends SignInState {
  const SignInInitial();
}

/// A sign-in or silent-auth attempt is in progress.
class SignInLoading extends SignInState {
  const SignInLoading();
}

/// User is authenticated and ready to use the app.
class Authenticated extends SignInState {
  final AuthUser user;
  const Authenticated(this.user);
}

/// No active session — show the sign-in screen without an error.
class Unauthenticated extends SignInState {
  const Unauthenticated();
}

/// Sign-out is in progress — show a fullscreen loading overlay.
class SigningOut extends SignInState {
  const SigningOut();
}

/// Interactive sign-in failed (network error, API rejection, etc.).
/// User cancelled silently resolves to [Unauthenticated] instead.
class SignInError extends SignInState {
  final String message;
  const SignInError(this.message);
}
