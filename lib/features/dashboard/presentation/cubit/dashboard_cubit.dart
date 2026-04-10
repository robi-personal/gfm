import 'package:bloc/bloc.dart';

import '../../domain/entities/form_entry.dart';
import '../../domain/usecases/create_form.dart';
import '../../domain/usecases/delete_form.dart';
import '../../domain/usecases/get_forms.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final GetForms _getForms;
  final CreateForm _createForm;
  final DeleteForm _deleteForm;

  DashboardCubit({
    required GetForms getForms,
    required CreateForm createForm,
    required DeleteForm deleteForm,
  })  : _getForms = getForms,
        _createForm = createForm,
        _deleteForm = deleteForm,
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

    final result = await _getForms(
      GetFormsParams(query: query, sortOrder: currentSort),
    );

    result.fold(
      (failure) => _emitError(failure.message, cached, currentSort),
      (forms) => emit(DashboardLoaded(
        forms: forms,
        query: query,
        sortOrder: currentSort,
      )),
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

  Future<void> search(String query) => loadForms(query: query);

  Future<void> refresh() async {
    final query =
        state is DashboardLoaded ? (state as DashboardLoaded).query : '';
    await loadForms(query: query);
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<void> createForm({String title = 'Untitled form'}) async {
    _setCreating(true);

    final result = await _createForm(CreateFormParams(title: title));

    result.fold(
      (failure) {
        _setCreating(false);
        throw Exception(failure.message);
      },
      (createResult) {
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
