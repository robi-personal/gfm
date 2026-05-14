import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/models/item.dart' as domain;
import '../../../../core/usecases/usecase.dart';
import '../../../../core/services/analytics_service.dart';
import '../../domain/entities/form_entry.dart';
import '../../domain/usecases/create_form.dart';
import '../../domain/usecases/delete_form.dart';
import '../../domain/usecases/get_forms.dart';
import '../../domain/usecases/get_imported_forms.dart';
import '../../domain/usecases/import_form.dart';
import '../../domain/usecases/remove_imported_form.dart';
import '../../domain/usecases/rename_form.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final GetForms _getForms;
  final CreateForm _createForm;
  final DeleteForm _deleteForm;
  final RenameForm _renameForm;
  final GetImportedForms _getImportedForms;
  final ImportForm _importForm;
  final RemoveImportedForm _removeImportedForm;

  Timer? _searchDebounce;

  DashboardCubit({
    required GetForms getForms,
    required CreateForm createForm,
    required DeleteForm deleteForm,
    required RenameForm renameForm,
    required GetImportedForms getImportedForms,
    required ImportForm importForm,
    required RemoveImportedForm removeImportedForm,
  })  : _getForms = getForms,
        _createForm = createForm,
        _deleteForm = deleteForm,
        _renameForm = renameForm,
        _getImportedForms = getImportedForms,
        _importForm = importForm,
        _removeImportedForm = removeImportedForm,
        super(const DashboardInitial());

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

    final formsResult = await _getForms(
      GetFormsParams(query: query, sortOrder: currentSort),
    );
    final importedResult = await _getImportedForms(const NoParams());

    formsResult.fold(
      (failure) => _emitError(failure.message, cached, currentSort),
      (owned) {
        final imported = importedResult.getOrElse(() => []);
        final ownedIds = owned.map((f) => f.id).toSet();
        final merged = [
          ...owned,
          ...imported.where((f) => !ownedIds.contains(f.id)),
        ];
        emit(DashboardLoaded(
          forms: merged,
          query: query,
          sortOrder: currentSort,
        ));
      },
    );
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

  void search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => loadForms(query: query),
    );
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  Future<void> refresh() async {
    final query =
        state is DashboardLoaded ? (state as DashboardLoaded).query : '';
    await loadForms(query: query);
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> createForm({
    String title = 'Untitled form',
    List<domain.Item>? items,
    bool enableQuiz = false,
  }) async {
    _setCreating(true);

    final result = await _createForm(
        CreateFormParams(title: title, items: items, enableQuiz: enableQuiz));

    result.fold(
      (failure) {
        _setCreating(false);
        throw Exception(failure.message);
      },
      (createResult) {
        AnalyticsService.logFormCreated();
        _setCreating(false,
            nav: CreateNavigation(
              formId: createResult.entry.id,
              formName: createResult.entry.name,
              publishFailed: createResult.publishFailed,
            ));
      },
    );
  }

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

    final result = await _deleteForm(DeleteFormParams(fileId));

    result.fold(
      (failure) {
        emit(loaded);
        throw Exception(failure.message);
      },
      (_) {},
    );
  }

  // ── Rename ─────────────────────────────────────────────────────────────────

  Future<void> renameForm(String fileId, String title) async {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;

    // Optimistic update + show loader on the card
    emit(loaded.copyWith(
      renamingId: fileId,
      forms: loaded.forms
          .map((f) => f.id == fileId ? f.copyWith(name: title) : f)
          .toList(),
    ));

    final result = await _renameForm(RenameFormParams(fileId, title));
    result.fold(
      (failure) {
        emit(loaded); // revert on failure
        throw Exception(failure.message);
      },
      (_) {
        if (state case DashboardLoaded()) {
          emit((state as DashboardLoaded).copyWith(clearRenaming: true));
        }
      },
    );
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> importForm(String formId) async {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;

    emit(loaded.copyWith(isImporting: true));

    final result = await _importForm(ImportFormParams(formId));

    result.fold(
      (failure) {
        emit(loaded.copyWith(isImporting: false));
        throw Exception(failure.message);
      },
      (entry) {
        final alreadyIn = loaded.forms.any((f) => f.id == formId);
        emit(loaded.copyWith(
          isImporting: false,
          forms: alreadyIn
              ? loaded.forms
              : [...loaded.forms, entry],
        ));
      },
    );
  }

  Future<void> removeImportedForm(String formId) async {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;

    emit(loaded.copyWith(
      forms: loaded.forms.where((f) => f.id != formId).toList(),
    ));

    final result =
        await _removeImportedForm(RemoveImportedFormParams(formId));
    result.fold(
      (failure) {
        emit(loaded);
        throw Exception(failure.message);
      },
      (_) {},
    );
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
    List<FormEntry>? cache,
    SortOrder sort,
  ) {
    emit(DashboardError(message: message, cachedForms: cache, sortOrder: sort));
  }
}
