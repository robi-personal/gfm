import 'package:dartz/dartz.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/editor_repository.dart';

class ExecuteBatchParams {
  final String formId;
  final List<forms_api.Request> requests;
  final String revisionId;

  const ExecuteBatchParams({
    required this.formId,
    required this.requests,
    required this.revisionId,
  });
}

/// Sends a batchUpdate via [EditorRepository].
/// Revision-mismatch retry is handled inside the repository.
class ExecuteBatch extends UseCase<BatchUpdateResult, ExecuteBatchParams> {
  final EditorRepository _repo;
  ExecuteBatch(this._repo);

  @override
  Future<Either<Failure, BatchUpdateResult>> call(ExecuteBatchParams params) =>
      _repo.batchUpdate(params.formId, params.requests, params.revisionId);
}
