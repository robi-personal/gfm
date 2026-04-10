import 'package:dartz/dartz.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/models/form_settings.dart';

/// Lightweight result returned from a successful batchUpdate call.
class BatchUpdateResult {
  /// Updated revision ID from the server response.
  final String revisionId;

  /// The server-assigned item ID from the first createItem reply, if any.
  final String? createdItemId;

  const BatchUpdateResult({required this.revisionId, this.createdItemId});
}

abstract class EditorRepository {
  /// Fetches the full form and parses it into a [FormDoc].
  Future<Either<Failure, FormDoc>> getForm(String formId);

  /// Fetches only the current revision ID (lightweight polling).
  Future<Either<Failure, String>> getRevisionId(String formId);

  /// Sends a batchUpdate. Handles revision-mismatch retry internally.
  /// Returns [RevisionMismatchFailure] on second consecutive mismatch.
  Future<Either<Failure, BatchUpdateResult>> batchUpdate(
    String formId,
    List<forms_api.Request> requests,
    String revisionId,
  );

  /// Applies quiz settings and email collection type.
  Future<Either<Failure, void>> updateSettings(
    String formId,
    FormSettings settings,
  );
}
