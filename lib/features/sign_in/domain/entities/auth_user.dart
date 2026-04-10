/// Authenticated user returned from the domain layer.
/// Contains only what the app actually needs — no SDK types leak out.
class AuthUser {
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}
