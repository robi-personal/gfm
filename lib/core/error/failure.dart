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

// ── AI Form Builder failures ──────────────────────────────────────────────────

/// 429 quota_exceeded — user's balance is insufficient for the generation.
class QuotaExceededFailure extends Failure {
  final String tier;
  final int balance;
  final int quotaCost;

  QuotaExceededFailure({
    required this.tier,
    required this.balance,
    required this.quotaCost,
    String message = 'Generation quota exceeded.',
  }) : super(message);
}

/// 403 premium_required — free user attempted a premium-only input type.
class PremiumRequiredFailure extends Failure {
  final String? requestedInputType;

  PremiumRequiredFailure({
    this.requestedInputType,
    String message = 'Premium subscription required.',
  }) : super(message);
}

/// 429 rate_limited — per-user or per-IP rate limit hit.
class RateLimitedFailure extends Failure {
  final int? retryAfterSeconds;

  RateLimitedFailure({
    this.retryAfterSeconds,
    String message = 'Too many requests.',
  }) : super(message);
}

/// 409 idempotency_conflict — same key reused with a different request body.
class IdempotencyConflictFailure extends Failure {
  const IdempotencyConflictFailure(
      [super.message = 'Idempotency key conflict.']);
}

/// 409 idempotency_in_flight — concurrent retry; first request still processing.
class IdempotencyInFlightFailure extends Failure {
  const IdempotencyInFlightFailure(
      [super.message = 'Request already in progress.']);
}

/// 403 user_blocked — user is on the server denylist.
class UserBlockedFailure extends Failure {
  const UserBlockedFailure([super.message = 'Account restricted.']);
}

/// 503 with a specific AI service error code (gemini_unavailable, gemini_timeout,
/// validation_error, service_disabled, service_busy, daily_budget_exceeded,
/// database_unavailable).
class AiServiceFailure extends Failure {
  final String code;

  AiServiceFailure({required this.code, String message = 'AI service error.'})
      : super(message);
}
