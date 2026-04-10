import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/editor_repository.dart';

/// Fetches and parses a form by ID.
/// Params: formId as [String].
class LoadForm extends UseCase<FormDoc, String> {
  final EditorRepository _repo;
  LoadForm(this._repo);

  @override
  Future<Either<Failure, FormDoc>> call(String formId) =>
      _repo.getForm(formId);
}
