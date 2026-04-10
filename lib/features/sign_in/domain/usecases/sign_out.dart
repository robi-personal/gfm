import '../repositories/auth_repository.dart';

/// Sign-out never fails — no Either wrapper needed.
class SignOut {
  final AuthRepository _repository;

  SignOut(this._repository);

  Future<void> call() => _repository.signOut();
}
