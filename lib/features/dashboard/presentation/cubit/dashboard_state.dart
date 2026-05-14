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
  final List<FormEntry> allForms;
  final String query;
  final SortOrder sortOrder;
  final bool isShowingCache;
  final bool isCreating;
  final bool isImporting;
  final String? renamingId;
  final CreateNavigation? createNav;

  const DashboardLoaded({
    required this.allForms,
    this.query = '',
    this.sortOrder = SortOrder.modifiedDesc,
    this.isShowingCache = false,
    this.isCreating = false,
    this.isImporting = false,
    this.renamingId,
    this.createNav,
  });

  List<FormEntry> get forms {
    if (query.isEmpty) return allForms;
    final q = query.toLowerCase();
    return allForms.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  DashboardLoaded copyWith({
    List<FormEntry>? allForms,
    String? query,
    SortOrder? sortOrder,
    bool? isShowingCache,
    bool? isCreating,
    bool? isImporting,
    String? renamingId,
    bool clearRenaming = false,
    CreateNavigation? createNav,
    bool clearNav = false,
  }) =>
      DashboardLoaded(
        allForms: allForms ?? this.allForms,
        query: query ?? this.query,
        sortOrder: sortOrder ?? this.sortOrder,
        isShowingCache: isShowingCache ?? this.isShowingCache,
        isCreating: isCreating ?? this.isCreating,
        isImporting: isImporting ?? this.isImporting,
        renamingId: clearRenaming ? null : (renamingId ?? this.renamingId),
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
