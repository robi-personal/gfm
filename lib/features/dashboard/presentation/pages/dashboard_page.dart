import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../../../../core/design.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/layout.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../../ai_form_builder/presentation/pages/ai_form_builder_page.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../paywall/data/services/subscription_service.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';
import '../widgets/dashboard_dialogs.dart';
import '../widgets/dashboard_drawer.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/dashboard_form_list.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_states.dart';
import '../widgets/dashboard_sub_header.dart';
import 'import_form_webview_page.dart';
import 'template_picker_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..loadForms(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late Future<bool> _isPremiumFuture;
  StreamSubscription<Map<String, String>>? _notificationTapSub;
  final _fabKey = GlobalKey<ExpandableFabState>();

  @override
  void initState() {
    super.initState();
    _isPremiumFuture = _fetchIsPremium();
    _notificationTapSub = getIt<NotificationService>()
        .onNotificationTap
        .listen(_handleNotificationTap);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _setupNotifications());
  }

  @override
  void dispose() {
    _notificationTapSub?.cancel();
    super.dispose();
  }

  Future<bool> _fetchIsPremium() => getIt<GetUserStatus>()
      .call(const NoParams())
      .then((r) => r.fold((_) => false, (s) => s.isPremium));

  void _refreshPremium() =>
      setState(() => _isPremiumFuture = _fetchIsPremium());

  Future<void> _showPaywall() async {
    await PaywallPage.show(context);
    if (!mounted) return;
    await pollUntilPremium(
      useCase: getIt<GetUserStatus>(),
      onPremiumConfirmed: () async {
        if (mounted) _refreshPremium();
      },
    );
  }

  Future<void> _restorePurchases() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
      ),
    );

    try {
      final info = await getIt<SubscriptionService>().restore();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final isPremium = info.entitlements.active.containsKey(SubscriptionService.entitlement);
      if (isPremium) {
        _refreshPremium();
        await ErrorModal.show(
          context,
          title: 'Purchases restored',
          body: 'Your subscription has been restored. Welcome back to Premium!',
          primaryLabel: 'OK',
          onPrimary: () {},
        );
      } else {
        await ErrorModal.show(
          context,
          title: 'No purchases found',
          body: "We couldn't find any active subscriptions on this Apple ID.",
          primaryLabel: 'OK',
          onPrimary: () {},
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await ErrorModal.show(
        context,
        title: 'Restore failed',
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    }
  }

  Future<void> _setupNotifications() async {
    if (!mounted) return;
    final svc = getIt<NotificationService>();
    final needsRationale = await svc.shouldShowRationale();
    if (!mounted) return;
    if (needsRationale) {
      bool accepted = false;
      await ErrorModal.show(
        context,
        title: 'Stay on top of new responses',
        body:
            'Get notified the moment someone submits to a form you\'ve enabled '
            'notifications on. You can change this anytime in Settings.',
        primaryLabel: 'Enable',
        onPrimary: () => accepted = true,
        secondaryLabel: 'Not now',
        onSecondary: () {},
      );
      if (!accepted) return;
    }
    await svc.registerForUser();
  }

  void _handleNotificationTap(Map<String, String> data) {
    final formId = data['formId'];
    if (formId == null || !mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EditorPage(
        formId: formId,
        formName: '',
        initialTabIndex: 1,
      ),
    ));
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _onNewForm(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const TemplatePickerPage(),
      ),
    ));
  }

  Future<void> _openImport(BuildContext context) async {
    final proceed = await showImportInfoDialog(context);
    if (proceed != true || !context.mounted) return;

    final cubit = context.read<DashboardCubit>();
    final formId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ImportFormWebViewPage()),
    );
    if (formId == null || !context.mounted) return;
    try {
      await cubit.importForm(formId);
    } catch (e) {
      if (context.mounted) {
        ErrorModal.show(
          context,
          title: 'Import failed',
          body: e.toString().replaceFirst('Exception: ', ''),
          primaryLabel: 'OK',
          onPrimary: () {},
        );
      }
    }
  }

  Future<void> _openAiBuilder(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AiFormBuilderPage()));
    if (context.mounted) context.read<DashboardCubit>().loadForms();
  }

  void _handleCreateNavigation(BuildContext context, CreateNavigation nav) async {
    final cubit = context.read<DashboardCubit>();
    cubit.clearNavigation();
    if (nav.publishFailed && context.mounted) {
      ErrorModal.show(
        context,
        title: 'Form created but not published.',
        body: "Responders can't submit until it's published. Publish now?",
        secondaryLabel: 'Later',
        onSecondary: () => _navigateToForm(context, nav),
        primaryLabel: 'Publish',
        onPrimary: () => _navigateToForm(context, nav),
      );
      return;
    }
    _navigateToForm(context, nav);
  }

  void _navigateToForm(BuildContext context, CreateNavigation nav) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorPage(formId: nav.formId, formName: nav.formName),
    ));
    if (context.mounted) context.read<DashboardCubit>().loadForms();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);

    return BlocConsumer<DashboardCubit, DashboardState>(
      listenWhen: (prev, curr) {
        final prevNav = prev is DashboardLoaded ? prev.createNav : null;
        final currNav = curr is DashboardLoaded ? curr.createNav : null;
        return currNav != null && currNav != prevNav;
      },
      listener: (context, state) {
        if (state case DashboardLoaded(:final createNav?)) {
          _handleCreateNavigation(context, createNav);
        }
      },
      builder: (context, state) {
        final isCreating = switch (state) {
          DashboardLoaded(:final isCreating) => isCreating,
          DashboardError(:final isCreating) => isCreating,
          _ => false,
        };
        final isImporting = state is DashboardLoaded && state.isImporting;

        final header = DashboardHeader(
          isTablet: tablet,
          isPremiumFuture: _isPremiumFuture,
          onShowPaywall: _showPaywall,
        );

        Widget body = _buildBody(context, state);
        if (isImporting) {
          body = Stack(children: [body, const DashboardImportingOverlay()]);
        }

        final drawer = DashboardDrawer(
          onAiBuilder: () => _openAiBuilder(context),
          onCreateForm: () => _onNewForm(context),
          onImportForm: () => _openImport(context),
          onShowPaywall: _showPaywall,
          onRestorePurchases: _restorePurchases,
        );

        if (tablet) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            resizeToAvoidBottomInset: false,
            appBar: header,
            body: Row(
              children: [
                SizedBox(width: 280, child: drawer),
                const VerticalDivider(
                    width: 1, thickness: 1, color: AppColors.hairline),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          resizeToAvoidBottomInset: false,
          appBar: header,
          drawer: drawer,
          body: body,
          floatingActionButtonLocation: ExpandableFab.location,
          floatingActionButton: DashboardFab(
            fabKey: _fabKey,
            isCreating: isCreating,
            onAiBuilder: () => _openAiBuilder(context),
            onCreateForm: () => _onNewForm(context),
            onImport: () => _openImport(context),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, DashboardState state) {
    return switch (state) {
      DashboardInitial() || DashboardLoading() => const DashboardSkeleton(),
      DashboardLoaded(
        :final allForms,
        :final forms,
        :final query,
        :final isShowingCache,
        :final sortOrder,
        :final renamingId,
      ) =>
        _buildLoaded(
          context,
          allForms: allForms,
          forms: forms,
          query: query,
          isShowingCache: isShowingCache,
          sortOrder: sortOrder,
          renamingId: renamingId,
        ),
      DashboardError(:final message, :final cachedForms) =>
        cachedForms != null
            ? Column(children: [
                DashboardInlineBanner(message: message),
                Expanded(
                    child: DashboardFormList(forms: cachedForms, query: '')),
              ])
            : DashboardFullScreenError(
                message: message,
                onRetry: () => context.read<DashboardCubit>().refresh(),
              ),
    };
  }

  Widget _buildLoaded(
    BuildContext context, {
    required List<FormEntry> allForms,
    required List<FormEntry> forms,
    required String query,
    required bool isShowingCache,
    required sortOrder,
    required String? renamingId,
  }) {
    return Column(
      children: [
        if (isShowingCache) const DashboardCacheBanner(),
        DashboardSubHeader(
          count: forms.length,
          query: query,
          sortOrder: sortOrder,
          onSort: () => context.read<DashboardCubit>().toggleSort(),
        ),
        Expanded(
          child: forms.isEmpty
              ? DashboardRefreshableEmptyState(query: query)
              : DashboardFormList(
                  forms: forms,
                  query: query,
                  renamingId: renamingId,
                ),
        ),
      ],
    );
  }
}
