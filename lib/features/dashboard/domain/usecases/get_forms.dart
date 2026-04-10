import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/form_entry.dart';
import '../repositories/form_repository.dart';

class GetFormsParams {
  final String query;
  final SortOrder sortOrder;

  const GetFormsParams({
    this.query = '',
    this.sortOrder = SortOrder.modifiedDesc,
  });
}

class GetForms implements UseCase<List<FormEntry>, GetFormsParams> {
  final FormRepository _repository;

  GetForms(this._repository);

  @override
  Future<Either<Failure, List<FormEntry>>> call(GetFormsParams params) =>
      _repository.getForms(query: params.query, sortOrder: params.sortOrder);
}
