import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_response.dart';

abstract class ResponsesRepository {
  Future<Either<Failure, List<FormResponse>>> getResponses(String formId);
}
