/// Authenticated user returned from the domain layer.
/// Contains only what the app actually needs — no SDK types leak out.
class AuthUser {
  /// Stable Google account identifier (the ID token `sub` claim).
  /// Used as the RevenueCat `app_user_id` so webhook lookups match the
  /// `users.google_sub` column on the backend.
  final String googleId;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.googleId,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}
