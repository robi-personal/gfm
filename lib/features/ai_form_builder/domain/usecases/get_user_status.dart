import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_status.dart';
import '../repositories/ai_form_repository.dart';

class GetUserStatus implements UseCase<UserStatus, NoParams> {
  final AiFormRepository _repository;

  GetUserStatus(this._repository);

  @override
  Future<Either<Failure, UserStatus>> call(NoParams params) =>
      _repository.getUserStatus();
}
