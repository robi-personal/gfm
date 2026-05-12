import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/form_repository.dart';

class RenameFormParams {
  final String fileId;
  final String title;

  const RenameFormParams(this.fileId, this.title);
}

class RenameForm implements UseCase<Unit, RenameFormParams> {
  final FormRepository _repository;

  RenameForm(this._repository);

  @override
  Future<Either<Failure, Unit>> call(RenameFormParams params) =>
      _repository.renameForm(params.fileId, params.title);
}
