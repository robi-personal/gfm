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

  Future<void> loadForms() async {
    final current = state;

    final cachedAll = switch (current) {
      DashboardLoaded(:final allForms) => allForms,
      DashboardError(:final cachedForms) => cachedForms,
      _ => null,
    };
    final currentSort = switch (current) {
      DashboardLoaded(:final sortOrder) => sortOrder,
      DashboardError(:final sortOrder) => sortOrder,
      _ => SortOrder.modifiedDesc,
    };
    final currentQuery = current is DashboardLoaded ? current.query : '';

    if (cachedAll == null) emit(const DashboardLoading());

    final formsResult = await _getForms(
      GetFormsParams(query: '', sortOrder: currentSort),
    );
    final importedResult = await _getImportedForms(const NoParams());

    formsResult.fold(
      (failure) => _emitError(failure.message, cachedAll, currentSort),
      (owned) {
        final imported = importedResult.getOrElse(() => []);
        final ownedIds = owned.map((f) => f.id).toSet();
        final merged = [
          ...owned,
          ...imported.where((f) => !ownedIds.contains(f.id)),
        ];
        emit(DashboardLoaded(
          allForms: merged,
          query: currentQuery,
          sortOrder: currentSort,
        ));
      },
    );
  }

  void search(String query) {
    if (state is! DashboardLoaded) return;
    emit((state as DashboardLoaded).copyWith(query: query));
  }

  void toggleSort() {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;
    final newSort = loaded.sortOrder == SortOrder.modifiedDesc
        ? SortOrder.createdDesc
        : SortOrder.modifiedDesc;
    final sorted = _sorted(loaded.allForms, newSort);
    emit(loaded.copyWith(allForms: sorted, sortOrder: newSort));
  }

  Future<void> refresh() => loadForms();

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
      allForms: loaded.allForms.where((f) => f.id != fileId).toList(),
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

    emit(loaded.copyWith(
      renamingId: fileId,
      allForms: loaded.allForms
          .map((f) => f.id == fileId ? f.copyWith(name: title) : f)
          .toList(),
    ));

    final result = await _renameForm(RenameFormParams(fileId, title));
    result.fold(
      (failure) {
        emit(loaded);
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
        final alreadyIn = loaded.allForms.any((f) => f.id == formId);
        emit(loaded.copyWith(
          isImporting: false,
          allForms: alreadyIn
              ? loaded.allForms
              : [...loaded.allForms, entry],
        ));
      },
    );
  }

  Future<void> removeImportedForm(String formId) async {
    if (state is! DashboardLoaded) return;
    final loaded = state as DashboardLoaded;

    emit(loaded.copyWith(
      allForms: loaded.allForms.where((f) => f.id != formId).toList(),
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

  List<FormEntry> _sorted(List<FormEntry> forms, SortOrder order) {
    final sorted = [...forms];
    sorted.sort((a, b) {
      final aTime = order == SortOrder.modifiedDesc ? a.modifiedTime : a.createdTime;
      final bTime = order == SortOrder.modifiedDesc ? b.modifiedTime : b.createdTime;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

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
