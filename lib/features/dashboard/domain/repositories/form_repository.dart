import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/form_entry.dart';

abstract class FormRepository {
  Future<Either<Failure, List<FormEntry>>> getForms({
    String query = '',
    SortOrder sortOrder = SortOrder.modifiedDesc,
  });

  Future<Either<Failure, CreateFormResult>> createForm({
    String title = 'Untitled form',
  });

  Future<Either<Failure, Unit>> deleteForm(String fileId);
}
