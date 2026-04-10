import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInSilently extends UseCase<AuthUser, NoParams> {
  final AuthRepository _repository;

  SignInSilently(this._repository);

  @override
  Future<Either<Failure, AuthUser>> call(NoParams _) =>
      _repository.signInSilently();
}
