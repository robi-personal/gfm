import 'dart:developer' as dev;
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/api/concurrency.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/models/form_settings.dart';
import '../../domain/repositories/editor_repository.dart';
import '../datasources/editor_datasource.dart';

class EditorRepositoryImpl implements EditorRepository {
  final EditorDataSource _datasource;

  EditorRepositoryImpl(this._datasource);

  // ── getForm ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, FormDoc>> getForm(String formId) async {
    try {
      return Right(await _datasource.getForm(formId));
    } on SocketException {
      return const Left(NetworkFailure());
    } catch (e, st) {
      dev.log('[EditorRepo] getForm error (status=${_status(e)}): $e',
          name: 'API', error: e, stackTrace: st);
      return Left(switch (_status(e)) {
        404 => const NotFoundFailure(),
        403 => const PermissionFailure(),
        _ => const ServerFailure(),
      });
    }
  }

  // ── getRevisionId ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, String>> getRevisionId(String formId) async {
    try {
      final doc = await _datasource.getForm(formId);
      return Right(doc.revisionId);
    } on SocketException {
      return const Left(NetworkFailure());
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  // ── batchUpdate (retry engine) ───────────────────────────────────────────

  @override
  Future<Either<Failure, BatchUpdateResult>> batchUpdate(
    String formId,
    List<forms_api.Request> requests,
    String revisionId,
  ) async {
    Future<BatchUpdateResult> call(String rev) =>
        _datasource.batchUpdate(formId, requests, rev);

    // ── First attempt ──────────────────────────────────────────────────────
    try {
      return Right(await call(revisionId));
    } catch (firstErr, firstSt) {
      dev.log(
        '[EditorRepo] batchUpdate error (status=${_status(firstErr)}): $firstErr',
        name: 'API',
        error: firstErr,
        stackTrace: firstSt,
      );

      // Revision mismatch → refresh + one retry
      if (isRevisionMismatch(firstErr)) {
        try {
          final doc = await _datasource.getForm(formId);
          final freshRev = doc.revisionId;
          try {
            return Right(await call(freshRev));
          } catch (secondErr) {
            if (isRevisionMismatch(secondErr)) {
              return const Left(RevisionMismatchFailure());
            }
            return Left(ServerFailure(_message(secondErr)));
          }
        } catch (_) {
          return const Left(RevisionMismatchFailure());
        }
      }

      // Non-revision 400 → bad payload, won't fix with retries
      if (_status(firstErr) == 400) {
        return Left(ServerFailure(_message(firstErr)));
      }

      // Network / 5xx → backoff retries (1s → 3s → 8s)
      for (final delay in [
        const Duration(seconds: 1),
        const Duration(seconds: 3),
        const Duration(seconds: 8),
      ]) {
        await Future<void>.delayed(delay);
        try {
          return Right(await call(revisionId));
        } catch (retryErr, retrySt) {
          dev.log(
            '[EditorRepo] batchUpdate retry error: $retryErr',
            name: 'API',
            error: retryErr,
            stackTrace: retrySt,
          );
          if (_status(retryErr) == 400) break; // give up on bad-request
        }
      }

      return firstErr is SocketException
          ? const Left(NetworkFailure())
          : const Left(ServerFailure());
    }
  }

  // ── updateSettings ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> updateSettings(
    String formId,
    FormSettings settings,
  ) async {
    try {
      await _datasource.updateSettings(formId, settings);
      return const Right(null);
    } on SocketException {
      return const Left(NetworkFailure());
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static int? _status(Object e) {
    try {
      return (e as dynamic).status as int?;
    } catch (_) {
      return null;
    }
  }

  static String _message(Object e) {
    try {
      return (e as dynamic).message as String? ?? 'Something went wrong.';
    } catch (_) {
      return 'Something went wrong.';
    }
  }
}
