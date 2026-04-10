import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/auth/google_auth_datasource.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final GoogleAuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, AuthUser>> signIn() async {
    final result = await _dataSource.signIn();
    return result.map(_toUser);
  }

  @override
  Future<Either<Failure, AuthUser>> signInSilently() async {
    final result = await _dataSource.signInSilently();
    return result.map(_toUser);
  }

  @override
  Future<void> signOut() => _dataSource.signOut();

  AuthUser _toUser(GoogleSignInAccount account) => AuthUser(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
}
