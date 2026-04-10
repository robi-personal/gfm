import 'dart:developer' as dev;
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:googleapis/drive/v3.dart' show File;
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../core/api/drive_client.dart';
import '../../core/api/forms_client.dart';
import '../../core/models/drive_form_entry.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DriveClient _driveClient;
  final FormsClient _formsClient;

  DashboardCubit(this._driveClient, this._formsClient)
      : super(const DashboardInitial());

  // ── List ──────────────────────────────────────────────────────────────────

  Future<void> loadForms({String query = ''}) async {
    final current = state;

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
        final escaped = query.replaceAll("'", "\\'");
        q.write(" and name contains '$escaped'");
      }

      final result = await _driveClient.api.files.list(
        q: q.toString(),
        orderBy: orderBy,
        $fields: 'files(id,name,modifiedTime,createdTime,webViewLink)',
      );

      final loadedForms =
          (result.files ?? []).map(DriveFormEntry.fromDriveFile).toList();

      emit(DashboardLoaded(
        forms: loadedForms,
        query: query,
        sortOrder: currentSort,
      ));
    } on SocketException catch (e) {
      dev.log('[DashboardCubit] loadForms network error: $e', name: 'API');
      _emitError(
          "Can't load your forms. Check your connection.", cached, currentSort);
    } catch (e, st) {
      dev.log('[DashboardCubit] loadForms error: $e', name: 'API', error: e, stackTrace: st);
      final status = _tryGetStatus(e);
      final message = switch (status) {
        500 || 503 => "Google Forms is having trouble. Try again in a moment.",
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
    final query =
        state is DashboardLoaded ? (state as DashboardLoaded).query : '';
    await loadForms(query: query);
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Two-step create: forms.create → setPublishSettings.
  /// On success emits [DashboardLoaded] with [CreateNavigation] set.
  /// Returns normally on publish failure (publishFailed=true in nav) so the
  /// screen can show the error modal before navigating.
  /// Throws on create failure so the screen can show the retry modal.
  Future<void> createForm() async {
    _setCreating(true);

    final forms_api.Form created;
    try {
      created = await _formsClient.api.forms.create(
        forms_api.Form(
          info: forms_api.Info(
            title: 'Untitled form',
            documentTitle: 'Untitled form',
          ),
        ),
      );
    } catch (e, st) {
      dev.log('[DashboardCubit] createForm error: $e', name: 'API', error: e, stackTrace: st);
      _setCreating(false);
      rethrow; // screen shows "Couldn't create form." modal
    }

    final formId = created.formId!;
    final formName = created.info?.title ?? 'Untitled form';

    // Step 2: add default short-answer question (spec §9 — no empty state).
    try {
      await _formsClient.api.forms.batchUpdate(
        forms_api.BatchUpdateFormRequest(
          requests: [
            forms_api.Request(
              createItem: forms_api.CreateItemRequest(
                item: forms_api.Item(
                  title: 'Question 1',
                  questionItem: forms_api.QuestionItem(
                    question: forms_api.Question(
                      required: false,
                      textQuestion: forms_api.TextQuestion(paragraph: false),
                    ),
                  ),
                ),
                location: forms_api.Location(index: 0),
              ),
            ),
          ],
        ),
        formId,
      );
    } catch (_) {
      // Non-fatal — the form exists, just has no questions yet.
      // The editor will show "No questions yet" which is still usable.
    }

    // Step 3: publish so responderUri works.
    bool publishFailed = false;
    try {
      await _formsClient.api.forms.setPublishSettings(
        forms_api.SetPublishSettingsRequest(
          publishSettings: forms_api.PublishSettings(
            publishState: forms_api.PublishState(
              isPublished: true,
              isAcceptingResponses: true,
            ),
          ),
        ),
        formId,
      );
    } catch (_) {
      publishFailed = true; // screen shows "not published" modal, still navigates
    }

    _setCreating(false, nav: CreateNavigation(
      formId: formId,
      formName: formName,
      publishFailed: publishFailed,
    ));
  }

  /// Called by the screen immediately after consuming [CreateNavigation].
  void clearNavigation() {
    if (state case DashboardLoaded()) {
      emit((state as DashboardLoaded).copyWith(clearNav: true));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteForm(String fileId) async {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;

    emit(loaded.copyWith(
      forms: loaded.forms.where((f) => f.id != fileId).toList(),
    ));

    try {
      await _driveClient.api.files.update(File()..trashed = true, fileId);
    } catch (e, st) {
      dev.log('[DashboardCubit] deleteForm error: $e', name: 'API', error: e, stackTrace: st);
      emit(loaded);
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setCreating(bool creating, {CreateNavigation? nav}) {
    switch (state) {
      case DashboardLoaded():
        emit((state as DashboardLoaded)
            .copyWith(isCreating: creating, createNav: nav));
      case DashboardError():
        final err = state as DashboardError;
        emit(DashboardError(
          message: err.message,
          cachedForms: err.cachedForms,
          sortOrder: err.sortOrder,
          isCreating: creating,
        ));
      default:
        break;
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
