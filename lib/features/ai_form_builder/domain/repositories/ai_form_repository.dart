import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/generated_form.dart';
import '../entities/quota_snapshot.dart';
import '../entities/user_status.dart';

class GenerateFormResult {
  final String generationId;
  final GeneratedForm form;
  final QuotaSnapshot? quota;

  const GenerateFormResult({
    required this.generationId,
    required this.form,
    this.quota,
  });
}

abstract class AiFormRepository {
  Future<Either<Failure, UserStatus>> getUserStatus();

  Future<Either<Failure, GenerateFormResult>> generateForm({
    required Map<String, dynamic> requestBody,
    required String idempotencyKey,
  });

  Future<Either<Failure, String>> createFormFromAi(GeneratedForm generatedForm);
}
