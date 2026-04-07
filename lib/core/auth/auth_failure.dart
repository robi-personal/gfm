sealed class AuthFailure {
  const AuthFailure();
}

class SignInCancelled extends AuthFailure {
  const SignInCancelled();
}

class SignInFailed extends AuthFailure {
  final String message;
  const SignInFailed(this.message);
}

class TokenExpired extends AuthFailure {
  const TokenExpired();
}
