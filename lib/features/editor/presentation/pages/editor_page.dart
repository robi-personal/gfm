import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/layout.dart';
import '../../../../core/widgets/error_modal.dart';
import 'tabs/questions/pages/questions_tab.dart';
import 'tabs/responses/cubit/responses_cubit.dart';
import 'tabs/responses/pages/responses_page.dart';
import '../cubit/editor_cubit.dart';
import '../widgets/editor_error_view.dart';
import '../widgets/editor_nav_rail.dart';
import '../widgets/editor_options_sheet.dart';
import 'tabs/settings/pages/editor_settings_tab.dart';
import '../widgets/editor_skeleton.dart';
import '../widgets/editor_tab_bar.dart';

class EditorPage extends StatelessWidget {
  final String formId;
  final String formName;
  final int initialTabIndex;

  const EditorPage({
    super.key,
    required this.formId,
    required this.formName,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<EditorCubit>()..loadForm(formId)),
        BlocProvider(create: (_) => getIt<ResponsesCubit>()..loadResponses(formId)),
      ],
      child: _EditorView(
        formId: formId,
        initialName: formName,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

// ── Main view (stateful for TabController) ────────────────────────────────────

class _EditorView extends StatefulWidget {
  final String formId;
  final String initialName;
  final int initialTabIndex;

  const _EditorView({
    required this.formId,
    required this.initialName,
    this.initialTabIndex = 0,
  });

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      animationDuration: Duration.zero,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) AnalyticsService.logResponsesViewed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleBackPress() async {
    final state = context.read<EditorCubit>().state;
    final isDirty = state is EditorLoaded && state.isDirty;
    if (!isDirty) {
      Navigator.of(context).pop();
      return;
    }
    bool discard = false;
    await ErrorModal.show(
      context,
      title: 'Discard changes?',
      body: 'You have unsaved changes. They will be lost if you go back.',
      primaryLabel: 'Keep editing',
      onPrimary: () {},
      secondaryLabel: 'Discard',
      onSecondary: () => discard = true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: BlocListener<EditorCubit, EditorState>(
      listener: _onStateChange,
      listenWhen: (prev, curr) {
        if (prev.runtimeType != curr.runtimeType) return true;
        if (curr is EditorLoaded) {
          final p = prev is EditorLoaded ? prev : null;
          if (curr.conflictPending && !(p?.conflictPending ?? false)) return true;
          if (curr.saveFailed && !(p?.saveFailed ?? false)) return true;
        }
        return curr is EditorError;
      },
      child: Scaffold(
        backgroundColor: AppColors.groupedBackground,
        appBar: _buildAppBar(context),
        body: BlocSelector<ResponsesCubit, ResponsesState, int?>(
          selector: (state) =>
              state is ResponsesLoaded ? state.responses.length : null,
          builder: (context, count) {
            final content = _buildContentStack(context);
            if (isTablet(context)) {
              return Row(
                children: [
                  EditorNavRail(
                      controller: _tabController, responseCount: count),
                  const VerticalDivider(
                      width: 1, thickness: 1, color: AppColors.separator),
                  Expanded(child: content),
                ],
              );
            }
            return Column(
              children: [
                EditorSegmentedTabBar(
                    controller: _tabController, responseCount: count),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.purple, size: 18),
        onPressed: _handleBackPress,
      ),
      title: Text(
        widget.initialName,
        style: AppTextStyles.screenHeader,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Save button
        BlocSelector<EditorCubit, EditorState,
            ({bool isLoaded, bool isDirty, bool isSaving})>(
          selector: (state) => state is EditorLoaded
              ? (
                  isLoaded: true,
                  isDirty: state.isDirty,
                  isSaving: state.isSaving
                )
              : (isLoaded: false, isDirty: false, isSaving: false),
          builder: (context, data) {
            final active = data.isLoaded && data.isDirty;
            return GestureDetector(
              onTap: active && !data.isSaving
                  ? () => context.read<EditorCubit>().save()
                  : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.purple
                      : AppColors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.isSaving)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CupertinoActivityIndicator(
                          radius: 6,
                          color: active ? Colors.white : AppColors.textSecondary,
                        ),
                      )
                    else
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 13,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      'Save',
                      style: AppTextStyles.meta.copyWith(
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Options button
        BlocSelector<EditorCubit, EditorState,
            ({bool isLoaded, String responderUri, String title})>(
          selector: (state) => state is EditorLoaded
              ? (
                  isLoaded: true,
                  responderUri: state.form.responderUri,
                  title: state.form.info.title.isNotEmpty
                      ? state.form.info.title
                      : state.form.info.documentTitle,
                )
              : (isLoaded: false, responderUri: '', title: ''),
          builder: (context, data) {
            return IconButton(
              icon: Icon(CupertinoIcons.ellipsis_vertical, color: AppColors.purple, size: 22),
              onPressed: data.isLoaded
                  ? () => _showOptionsSheet(
                      context, data.responderUri, data.title)
                  : null,
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildContentStack(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: AppColors.groupedBackground,
        child: BlocBuilder<EditorCubit, EditorState>(
          buildWhen: (prev, curr) {
            if (prev.runtimeType != curr.runtimeType) return true;
            if (prev is EditorLoaded && curr is EditorLoaded) {
              return prev.isSaving != curr.isSaving;
            }
            return false;
          },
          builder: (context, state) => switch (state) {
            EditorLoading() => const EditorSkeleton(),
            EditorLoaded(:final isSaving) when isSaving => const EditorSkeleton(),
            EditorError(:final kind, :final message)
                when kind == EditorErrorKind.network =>
              EditorErrorView(
                message: message,
                onRetry: () =>
                    context.read<EditorCubit>().loadForm(widget.formId),
              ),
            EditorError() => const SizedBox.shrink(),
            EditorLoaded(:final form) => TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  QuestionsTab(formId: widget.formId),
                  BlocProvider.value(
                    value: context.read<ResponsesCubit>(),
                    child: ResponsesScreen(
                      formId: widget.formId,
                      items: form.items,
                    ),
                  ),
                  EditorSettingsTab(formId: widget.formId),
                ],
              ),
          },
        ),
      ),
    );
  }

  void _showOptionsSheet(
      BuildContext context, String responderUri, String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EditorOptionsSheet(
        responderUri: responderUri,
        title: title,
      ),
    );
  }

  void _onStateChange(BuildContext context, EditorState state) {
    if (state case EditorLoaded(conflictPending: true)) {
      context.read<EditorCubit>().clearConflict();
      ErrorModal.show(
        context,
        title: 'This form was edited somewhere else.',
        body: 'Keep your version or load the latest?',
        primaryLabel: 'Keep mine',
        onPrimary: () =>
            context.read<EditorCubit>().resolveConflictKeepMine(),
        secondaryLabel: 'Load latest',
        onSecondary: () =>
            context.read<EditorCubit>().resolveConflictLoadLatest(),
      );
    }

    if (state case EditorLoaded(saveFailed: true)) {
      context.read<EditorCubit>().clearSaveFailed();
      ErrorModal.show(
        context,
        title: "Couldn't save your changes.",
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    }

    if (state case EditorError(:final kind)) {
      switch (kind) {
        case EditorErrorKind.notFound:
          ErrorModal.show(
            context,
            title: 'This form was deleted.',
            body: "It's no longer available in your Drive.",
            primaryLabel: 'OK',
            onPrimary: () => Navigator.of(context).pop(),
          );
        case EditorErrorKind.permissionDenied:
          ErrorModal.show(
            context,
            title: "You don't have access to this form.",
            body: 'The owner may have revoked your access.',
            primaryLabel: 'OK',
            onPrimary: () => Navigator.of(context).pop(),
          );
        case EditorErrorKind.network:
          break;
      }
    }
  }
}
