import 'dart:developer' as dev;
import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_response.dart';
import '../../domain/repositories/responses_repository.dart';
import '../datasources/responses_datasource.dart';

class ResponsesRepositoryImpl implements ResponsesRepository {
  final ResponsesDataSource _dataSource;

  ResponsesRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<FormResponse>>> getResponses(
      String formId) async {
    try {
      final responses = await _dataSource.getResponses(formId);
      return Right(responses);
    } on SocketException catch (e) {
      dev.log('[ResponsesRepository] network error: $e', name: 'API');
      return Left(NetworkFailure("Can't load responses. Check your connection."));
    } catch (e, st) {
      dev.log('[ResponsesRepository] error: $e',
          name: 'API', error: e, stackTrace: st);
      return Left(ServerFailure("Couldn't load responses."));
    }
  }
}
