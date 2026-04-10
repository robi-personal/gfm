import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/form_entry.dart';
import '../repositories/form_repository.dart';

class CreateFormParams {
  final String title;

  const CreateFormParams({this.title = 'Untitled form'});
}

class CreateForm implements UseCase<CreateFormResult, CreateFormParams> {
  final FormRepository _repository;

  CreateForm(this._repository);

  @override
  Future<Either<Failure, CreateFormResult>> call(CreateFormParams params) =>
      _repository.createForm(title: params.title);
}
