import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/editor_repository.dart';

/// Returns the latest revision ID for a form.
/// Params: formId as [String].
class RefreshRevision extends UseCase<String, String> {
  final EditorRepository _repo;
  RefreshRevision(this._repo);

  @override
  Future<Either<Failure, String>> call(String formId) =>
      _repo.getRevisionId(formId);
}
