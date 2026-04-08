part of 'dashboard_cubit.dart';

enum SortOrder { modifiedDesc, createdDesc }

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

  /// True when we are showing a previously-cached list while a refresh is in
  /// progress or after a transient failure. Shown as an inline banner.
  final bool isShowingCache;

  const DashboardLoaded({
    required this.forms,
    this.query = '',
    this.sortOrder = SortOrder.modifiedDesc,
    this.isShowingCache = false,
  });

  DashboardLoaded copyWith({
    List<DriveFormEntry>? forms,
    String? query,
    SortOrder? sortOrder,
    bool? isShowingCache,
  }) =>
      DashboardLoaded(
        forms: forms ?? this.forms,
        query: query ?? this.query,
        sortOrder: sortOrder ?? this.sortOrder,
        isShowingCache: isShowingCache ?? this.isShowingCache,
      );
}

class DashboardError extends DashboardState {
  final String message;

  /// If we have a cached list, show it beneath the error banner instead of
  /// a full-screen error.
  final List<DriveFormEntry>? cachedForms;
  final SortOrder sortOrder;

  const DashboardError({
    required this.message,
    this.cachedForms,
    this.sortOrder = SortOrder.modifiedDesc,
  });
}
