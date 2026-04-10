import 'dart:developer' as dev;
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/error/failure.dart';
import '../../domain/entities/form_entry.dart';
import '../../domain/repositories/form_repository.dart';
import '../datasources/drive_datasource.dart';
import '../datasources/forms_datasource.dart';
import '../models/form_entry_model.dart';

class FormRepositoryImpl implements FormRepository {
  final DriveDataSource _drive;
  final FormsDataSource _forms;

  FormRepositoryImpl(this._drive, this._forms);

  @override
  Future<Either<Failure, List<FormEntry>>> getForms({
    String query = '',
    SortOrder sortOrder = SortOrder.modifiedDesc,
  }) async {
    try {
      final orderBy = sortOrder == SortOrder.modifiedDesc
          ? 'modifiedTime desc'
          : 'createdTime desc';
      final forms = await _drive.listForms(query: query, orderBy: orderBy);
      return Right(forms);
    } on SocketException catch (e) {
      dev.log('[FormRepository] getForms network error: $e', name: 'API');
      return Left(NetworkFailure("Can't load your forms. Check your connection."));
    } catch (e, st) {
      dev.log('[FormRepository] getForms error: $e', name: 'API', error: e, stackTrace: st);
      final status = _tryGetStatus(e);
      return Left(status == 500 || status == 503
          ? ServerFailure('Google Forms is having trouble. Try again in a moment.')
          : NetworkFailure("Can't load your forms. Check your connection."));
    }
  }

  @override
  Future<Either<Failure, CreateFormResult>> createForm({
    String title = 'Untitled form',
  }) async {
    final forms_api.Form created;
    try {
      created = await _forms.createForm(title);
    } catch (e, st) {
      dev.log('[FormRepository] createForm error: $e', name: 'API', error: e, stackTrace: st);
      return Left(ServerFailure("Couldn't create form."));
    }

    final formId = created.formId!;
    final formName = created.info?.title ?? 'Untitled form';
    final entry = FormEntryModel(id: formId, name: formName);

    try {
      await _forms.addDefaultQuestion(formId);
    } catch (_) {}

    bool publishFailed = false;
    try {
      await _forms.publishForm(formId);
    } catch (e, st) {
      dev.log('[FormRepository] publishForm error: $e', name: 'API', error: e, stackTrace: st);
      publishFailed = true;
    }

    return Right(CreateFormResult(entry: entry, publishFailed: publishFailed));
  }

  @override
  Future<Either<Failure, Unit>> deleteForm(String fileId) async {
    try {
      await _drive.trashFile(fileId);
      return const Right(unit);
    } on SocketException catch (e) {
      dev.log('[FormRepository] deleteForm network error: $e', name: 'API');
      return Left(NetworkFailure());
    } catch (e, st) {
      dev.log('[FormRepository] deleteForm error: $e', name: 'API', error: e, stackTrace: st);
      return Left(ServerFailure());
    }
  }
}

int? _tryGetStatus(Object e) {
  try {
    return (e as dynamic).status as int?;
  } catch (_) {
    return null;
  }
}
