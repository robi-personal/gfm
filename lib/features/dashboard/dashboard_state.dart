part of 'dashboard_cubit.dart';

enum SortOrder { modifiedDesc, createdDesc }

/// Set on [DashboardLoaded] after a form is successfully created.
/// Consumed by the screen via BlocListener then cleared with
/// [DashboardCubit.clearNavigation].
class CreateNavigation {
  final String formId;
  final String formName;

  /// True when create succeeded but publish failed. The editor should show
  /// an "Unpublished" pill and surface the publish-failure modal.
  final bool publishFailed;

  const CreateNavigation({
    required this.formId,
    required this.formName,
    this.publishFailed = false,
  });
}

sealed class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final List<DriveFormEntry> forms;
  final String query;
  final SortOrder sortOrder;
  final bool isShowingCache;

  /// True while a form-create request is in flight. Disables the FAB.
  final bool isCreating;

  /// Non-null for exactly one emit after successful create. The screen
  /// navigates and then calls [DashboardCubit.clearNavigation].
  final CreateNavigation? createNav;

  const DashboardLoaded({
    required this.forms,
    this.query = '',
    this.sortOrder = SortOrder.modifiedDesc,
    this.isShowingCache = false,
    this.isCreating = false,
    this.createNav,
  });

  DashboardLoaded copyWith({
    List<DriveFormEntry>? forms,
    String? query,
    SortOrder? sortOrder,
    bool? isShowingCache,
    bool? isCreating,
    CreateNavigation? createNav,
    bool clearNav = false,
  }) =>
      DashboardLoaded(
        forms: forms ?? this.forms,
        query: query ?? this.query,
        sortOrder: sortOrder ?? this.sortOrder,
        isShowingCache: isShowingCache ?? this.isShowingCache,
        isCreating: isCreating ?? this.isCreating,
        createNav: clearNav ? null : (createNav ?? this.createNav),
      );
}

class DashboardError extends DashboardState {
  final String message;
  final List<DriveFormEntry>? cachedForms;
  final SortOrder sortOrder;
  final bool isCreating;

  const DashboardError({
    required this.message,
    this.cachedForms,
    this.sortOrder = SortOrder.modifiedDesc,
    this.isCreating = false,
  });
}
