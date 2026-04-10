import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/form_repository.dart';

class DeleteFormParams {
  final String fileId;

  const DeleteFormParams(this.fileId);
}

class DeleteForm implements UseCase<Unit, DeleteFormParams> {
  final FormRepository _repository;

  DeleteForm(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteFormParams params) =>
      _repository.deleteForm(params.fileId);
}
