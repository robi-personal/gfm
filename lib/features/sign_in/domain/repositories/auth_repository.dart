import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  /// Interactive Google Sign-In. Returns [AuthCancelledFailure] if the user
  /// dismisses the picker without signing in.
  Future<Either<Failure, AuthUser>> signIn();

  /// Silent sign-in using cached credentials. Returns [AuthCancelledFailure]
  /// when no cached session exists (user must sign in interactively).
  Future<Either<Failure, AuthUser>> signInSilently();

  /// Clears the current session. Never fails.
  Future<void> signOut();
}
