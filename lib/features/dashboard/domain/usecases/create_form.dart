import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/item.dart' as domain;
import '../../../../core/usecases/usecase.dart';
import '../entities/form_entry.dart';
import '../repositories/form_repository.dart';

class CreateFormParams {
  final String title;
  final List<domain.Item>? items;
  final bool enableQuiz;

  const CreateFormParams({this.title = 'Untitled form', this.items, this.enableQuiz = false});
}

class CreateForm implements UseCase<CreateFormResult, CreateFormParams> {
  final FormRepository _repository;

  CreateForm(this._repository);

  @override
  Future<Either<Failure, CreateFormResult>> call(CreateFormParams params) =>
      _repository.createForm(title: params.title, items: params.items, enableQuiz: params.enableQuiz);
}
