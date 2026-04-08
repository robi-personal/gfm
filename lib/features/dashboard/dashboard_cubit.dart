import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:googleapis/drive/v3.dart' show File;

import '../../core/api/drive_client.dart';
import '../../core/models/drive_form_entry.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DriveClient _driveClient;

  DashboardCubit(this._driveClient) : super(const DashboardInitial());

  Future<void> loadForms({String query = ''}) async {
    final current = state;

    // Keep existing data visible while refreshing.
    final cached = switch (current) {
      DashboardLoaded(:final forms) => forms,
      DashboardError(:final cachedForms) => cachedForms,
      _ => null,
    };
    final currentSort = switch (current) {
      DashboardLoaded(:final sortOrder) => sortOrder,
      DashboardError(:final sortOrder) => sortOrder,
      _ => SortOrder.modifiedDesc,
    };

    if (cached == null) emit(const DashboardLoading());

    try {
      final orderBy = currentSort == SortOrder.modifiedDesc
          ? 'modifiedTime desc'
          : 'createdTime desc';

      final q = StringBuffer(
          "mimeType='application/vnd.google-apps.form' and trashed=false");
      if (query.isNotEmpty) {
        // Escape single quotes inside the query string per Drive API rules.
        final escaped = query.replaceAll("'", "\\'");
        q.write(" and name contains '$escaped'");
      }

      final result = await _driveClient.api.files.list(
        q: q.toString(),
        orderBy: orderBy,
        $fields: 'files(id,name,modifiedTime,createdTime,webViewLink)',
      );

      final forms = (result.files ?? [])
          .map(DriveFormEntry.fromDriveFile)
          .toList();

      emit(DashboardLoaded(
        forms: forms,
        query: query,
        sortOrder: currentSort,
      ));
    } on SocketException {
      _emitError(
        "Can't load your forms. Check your connection.",
        cached,
        currentSort,
      );
    } catch (e) {
      final status = _tryGetStatus(e);
      final message = switch (status) {
        500 || 503 =>
          "Google Forms is having trouble. Try again in a moment.",
        _ => "Can't load your forms. Check your connection.",
      };
      _emitError(message, cached, currentSort);
    }
  }

  Future<void> toggleSort() async {
    final current = state;
    if (current is! DashboardLoaded) return;
    final newSort = current.sortOrder == SortOrder.modifiedDesc
        ? SortOrder.createdDesc
        : SortOrder.modifiedDesc;
    emit(current.copyWith(sortOrder: newSort));
    await loadForms(query: current.query);
  }

  Future<void> search(String query) => loadForms(query: query);

  Future<void> refresh() async {
    final query = switch (state) {
      DashboardLoaded(:final query) => query,
      _ => '',
    };
    await loadForms(query: query);
  }

  /// Soft-trashes a form. Rolls back on failure.
  Future<void> deleteForm(String fileId) async {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;

    // Optimistic remove.
    emit(loaded.copyWith(
      forms: loaded.forms.where((f) => f.id != fileId).toList(),
    ));

    try {
      await _driveClient.api.files.update(
        File()..trashed = true,
        fileId,
      );
    } catch (_) {
      // Roll back — re-insert the form by reloading.
      emit(loaded);
      rethrow;
    }
  }

  void _emitError(
    String message,
    List<DriveFormEntry>? cache,
    SortOrder sort,
  ) {
    emit(DashboardError(message: message, cachedForms: cache, sortOrder: sort));
  }
}

int? _tryGetStatus(Object e) {
  try {
    return (e as dynamic).status as int?;
  } catch (_) {
    return null;
  }
}

