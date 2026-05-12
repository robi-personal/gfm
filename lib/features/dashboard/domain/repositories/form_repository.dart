import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/item.dart' as domain;
import '../entities/form_entry.dart';

abstract class FormRepository {
  Future<Either<Failure, List<FormEntry>>> getForms({
    String query = '',
    SortOrder sortOrder = SortOrder.modifiedDesc,
  });

  Future<Either<Failure, CreateFormResult>> createForm({
    String title = 'Untitled form',
    List<domain.Item>? items,
    bool enableQuiz = false,
  });

  Future<Either<Failure, Unit>> deleteForm(String fileId);

  Future<Either<Failure, Unit>> renameForm(String fileId, String title);
}
