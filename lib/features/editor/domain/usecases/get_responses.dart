import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_response.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/responses_repository.dart';

class GetResponses implements UseCase<List<FormResponse>, String> {
  final ResponsesRepository _repository;

  GetResponses(this._repository);

  @override
  Future<Either<Failure, List<FormResponse>>> call(String formId) =>
      _repository.getResponses(formId);
}
