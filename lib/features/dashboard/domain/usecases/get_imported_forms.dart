import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/form_entry.dart';
import '../repositories/form_repository.dart';

class GetImportedForms implements UseCase<List<FormEntry>, NoParams> {
  final FormRepository _repository;

  GetImportedForms(this._repository);

  @override
  Future<Either<Failure, List<FormEntry>>> call(NoParams params) =>
      _repository.getImportedForms();
}
