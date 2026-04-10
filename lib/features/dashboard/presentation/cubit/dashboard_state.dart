part of 'dashboard_cubit.dart';

class CreateNavigation {
  final String formId;
  final String formName;
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
  final List<FormEntry> forms;
  final String query;
  final SortOrder sortOrder;
  final bool isShowingCache;
  final bool isCreating;
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
    List<FormEntry>? forms,
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
  final List<FormEntry>? cachedForms;
  final SortOrder sortOrder;
  final bool isCreating;

  const DashboardError({
    required this.message,
    this.cachedForms,
    this.sortOrder = SortOrder.modifiedDesc,
    this.isCreating = false,
  });
}
