import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/form_repository.dart';

class RemoveImportedFormParams {
  final String formId;
  const RemoveImportedFormParams(this.formId);
}

class RemoveImportedForm implements UseCase<Unit, RemoveImportedFormParams> {
  final FormRepository _repository;

  RemoveImportedForm(this._repository);

  @override
  Future<Either<Failure, Unit>> call(RemoveImportedFormParams params) =>
      _repository.removeImportedForm(params.formId);
}
