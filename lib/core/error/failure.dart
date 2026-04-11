/// Base class for all domain-layer failures.
/// Data layer catches exceptions and maps them to these types.
sealed class Failure {
  final String message;
  const Failure(this.message);
}

/// No internet / socket error.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// Google Sign-In was cancelled by the user.
class AuthCancelledFailure extends Failure {
  const AuthCancelledFailure([super.message = 'Sign-in was cancelled.']);
}

/// Authentication failed for any other reason (token error, API rejection, etc.).
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

/// The server returned an unexpected error (5xx, malformed response, etc.).
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong.']);
}

/// The requested resource was not found (404).
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}

/// Access to the resource was denied (403).
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied.']);
}

/// The write was rejected because the form revision is out of date.
class RevisionMismatchFailure extends Failure {
  const RevisionMismatchFailure(
      [super.message = 'Form was edited elsewhere.']);
}
