import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/ai_form_repository.dart';

class GenerateFormParams {
  final Map<String, dynamic> requestBody;
  final String idempotencyKey;

  const GenerateFormParams({
    required this.requestBody,
    required this.idempotencyKey,
  });
}

class GenerateForm implements UseCase<GenerateFormResult, GenerateFormParams> {
  final AiFormRepository _repository;

  GenerateForm(this._repository);

  @override
  Future<Either<Failure, GenerateFormResult>> call(GenerateFormParams params) =>
      _repository.generateForm(
        requestBody: params.requestBody,
        idempotencyKey: params.idempotencyKey,
      );
}
