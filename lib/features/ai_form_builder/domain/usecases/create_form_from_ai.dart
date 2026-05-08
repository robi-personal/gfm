import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/generated_form.dart';
import '../repositories/ai_form_repository.dart';

class CreateFormFromAiParams {
  final GeneratedForm generatedForm;

  const CreateFormFromAiParams({required this.generatedForm});
}

class CreateFormFromAi implements UseCase<String, CreateFormFromAiParams> {
  final AiFormRepository _repository;

  CreateFormFromAi(this._repository);

  @override
  Future<Either<Failure, String>> call(CreateFormFromAiParams params) =>
      _repository.createFormFromAi(params.generatedForm);
}
