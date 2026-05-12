import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/form_entry.dart';
import '../repositories/form_repository.dart';

class ImportFormParams {
  final String formId;
  const ImportFormParams(this.formId);
}

class ImportForm implements UseCase<FormEntry, ImportFormParams> {
  final FormRepository _repository;

  ImportForm(this._repository);

  @override
  Future<Either<Failure, FormEntry>> call(ImportFormParams params) =>
      _repository.importForm(params.formId);
}
