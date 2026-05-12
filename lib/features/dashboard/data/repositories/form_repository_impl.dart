import 'dart:developer' as dev;
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/error/failure.dart';
import '../../../../core/models/item.dart' as domain;
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
    List<domain.Item>? items,
    bool enableQuiz = false,
  }) async {
    final forms_api.Form created;
    try {
      created = await _forms.createForm(title, documentTitle: title);
    } catch (e, st) {
      dev.log('[FormRepository] createForm error: $e', name: 'API', error: e, stackTrace: st);
      return Left(ServerFailure("Couldn't create form."));
    }

    final formId = created.formId!;
    final formName = created.info?.title ?? 'Untitled form';
    final entry = FormEntryModel(id: formId, name: formName);

    try {
      if (items != null && items.isNotEmpty) {
        await _forms.addTemplateItems(formId, items);
      } else {
        await _forms.addDefaultQuestion(formId);
      }
    } catch (e, st) {
      dev.log('[FormRepository] addTemplateItems error: $e', name: 'API', error: e, stackTrace: st);
    }

    if (enableQuiz) {
      try {
        await _forms.enableQuizMode(formId);
      } catch (_) {}
    }

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

  @override
  Future<Either<Failure, Unit>> renameForm(String fileId, String title) async {
    try {
      await Future.wait([
        _drive.renameFile(fileId, title),
        _forms.updateTitle(fileId, title),
      ]);
      return const Right(unit);
    } on SocketException catch (e) {
      dev.log('[FormRepository] renameForm network error: $e', name: 'API');
      return Left(NetworkFailure("Couldn't rename. Check your connection."));
    } catch (e, st) {
      dev.log('[FormRepository] renameForm error: $e', name: 'API', error: e, stackTrace: st);
      return Left(ServerFailure("Couldn't rename the form."));
    }
  }

  @override
  Future<Either<Failure, List<FormEntry>>> getImportedForms() async {
    try {
      final ids = await _drive.readImportedFormIds();
      if (ids.isEmpty) return const Right([]);

      final entries = await Future.wait(
        ids.map((id) async {
          try {
            final f = await _forms.getForm(id);
            return FormEntry(
              id: id,
              name: f.info?.title ?? 'Untitled form',
              isOwned: false,
            );
          } catch (_) {
            return null;
          }
        }),
      );

      return Right(entries.whereType<FormEntry>().toList());
    } on SocketException catch (e) {
      dev.log('[FormRepository] getImportedForms network error: $e', name: 'API');
      return const Right([]);
    } catch (e, st) {
      dev.log('[FormRepository] getImportedForms error: $e', name: 'API', error: e, stackTrace: st);
      return const Right([]);
    }
  }

  @override
  Future<Either<Failure, FormEntry>> importForm(String formId) async {
    try {
      final form = await _forms.getForm(formId);
      final name = form.info?.title ?? 'Untitled form';

      final ids = await _drive.readImportedFormIds();
      if (!ids.contains(formId)) {
        await _drive.writeImportedFormIds([...ids, formId]);
      }

      return Right(FormEntry(id: formId, name: name, isOwned: false));
    } on SocketException catch (e) {
      dev.log('[FormRepository] importForm network error: $e', name: 'API');
      return Left(NetworkFailure("Couldn't import. Check your connection."));
    } catch (e, st) {
      dev.log('[FormRepository] importForm error: $e', name: 'API', error: e, stackTrace: st);
      final status = _tryGetStatus(e);
      if (status == 404) return Left(NotFoundFailure("Form not found."));
      if (status == 403) return Left(PermissionFailure("You don't have access to this form."));
      return Left(ServerFailure("Couldn't import form."));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeImportedForm(String formId) async {
    try {
      final ids = await _drive.readImportedFormIds();
      await _drive.writeImportedFormIds(
          ids.where((id) => id != formId).toList());
      return const Right(unit);
    } on SocketException catch (e) {
      dev.log('[FormRepository] removeImportedForm network error: $e', name: 'API');
      return Left(NetworkFailure("Couldn't remove. Check your connection."));
    } catch (e, st) {
      dev.log('[FormRepository] removeImportedForm error: $e', name: 'API', error: e, stackTrace: st);
      return Left(ServerFailure("Couldn't remove imported form."));
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
