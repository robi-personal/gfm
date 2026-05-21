import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/design.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/layout.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../../ai_form_builder/presentation/pages/ai_form_builder_page.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../../notifications/data/services/notification_service.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';
import '../widgets/dashboard_drawer.dart';
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

  // ── Navigation helpers ──────────────────────────────────────────────────────

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
    // The info dialog is shown from here so we have a BuildContext with Scaffold.
    final proceed = await _showImportInfoDialogLocal(context);
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

  void _handleCreateNavigation(
      BuildContext context, CreateNavigation nav) async {
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
      builder: (_) =>
          EditorPage(formId: nav.formId, formName: nav.formName),
    ));
    if (context.mounted) context.read<DashboardCubit>().loadForms();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tablet = isTablet(context);

    return BlocConsumer<DashboardCubit, DashboardState>(
      listenWhen: (prev, curr) {
        final prevNav =
            prev is DashboardLoaded ? prev.createNav : null;
        final currNav =
            curr is DashboardLoaded ? curr.createNav : null;
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
        final isImporting =
            state is DashboardLoaded && state.isImporting;

        final header = DashboardHeader(
          isTablet: tablet,
          isPremiumFuture: _isPremiumFuture,
          onShowPaywall: _showPaywall,
        );

        Widget body = _buildBody(context, state);
        if (isImporting) {
          body = Stack(children: [body, const DashboardImportingOverlay()]);
        }

        if (tablet) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            resizeToAvoidBottomInset: false,
            appBar: header,
            body: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: _tabletSidebar(context),
                ),
                const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.hairline),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.bg,
          resizeToAvoidBottomInset: false,
          appBar: header,
          drawer: DashboardDrawer(
            onAiBuilder: () => _openAiBuilder(context),
            onCreateForm: () => _onNewForm(context),
            onImportForm: () => _openImport(context),
            onShowPaywall: _showPaywall,
          ),
          body: body,
          floatingActionButtonLocation: ExpandableFab.location,
          floatingActionButton: _buildFab(context, isCreating),
        );
      },
    );
  }

  Widget _tabletSidebar(BuildContext context) {
    return DashboardDrawer(
      onAiBuilder: () => _openAiBuilder(context),
      onCreateForm: () => _onNewForm(context),
      onImportForm: () => _openImport(context),
      onShowPaywall: _showPaywall,
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────

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
                    child: DashboardFormList(
                        forms: cachedForms, query: '')),
              ])
            : DashboardFullScreenError(
                message: message,
                onRetry: () =>
                    context.read<DashboardCubit>().refresh(),
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

  // ── FAB ─────────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context, bool isCreating) {
    return ExpandableFab(
      key: _fabKey,
      type: ExpandableFabType.up,
      distance: 75,
      duration: const Duration(milliseconds: 220),
      overlayStyle: ExpandableFabOverlayStyle(
        color: const Color(0xFF141028).withValues(alpha: 0.35),
        blur: 3.0,
      ),
      openButtonBuilder: RotateFloatingActionButtonBuilder(
        child: isCreating
            ? const CupertinoActivityIndicator(
                radius: 10, color: Colors.white)
            : const Icon(Icons.add_rounded, size: 26),
        fabSize: ExpandableFabSize.regular,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.purple,
        shape: const CircleBorder(),
      ),
      closeButtonBuilder: DefaultFloatingActionButtonBuilder(
        child: const Icon(Icons.close_rounded, size: 22),
        fabSize: ExpandableFabSize.regular,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.purple,
        shape: const CircleBorder(),
      ),
      children: [
        _FabAction(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Form Builder',
          color: AppColors.purpleAccent,
          lottieAsset: 'assets/lottie/aiFormBuilder.json',
          onTap: isCreating
              ? null
              : () {
                  _fabKey.currentState?.toggle();
                  _openAiBuilder(context);
                },
        ),
        _FabAction(
          icon: Icons.edit_note_rounded,
          label: 'Create Form',
          color: AppColors.purple,
          lottieAsset: 'assets/lottie/createForm.json',
          lottieSize: 75,
          onTap: isCreating
              ? null
              : () {
                  _fabKey.currentState?.toggle();
                  _onNewForm(context);
                },
        ),
        _FabAction(
          icon: CupertinoIcons.link,
          label: 'Import Form',
          color: AppColors.purple,
          onTap: isCreating
              ? null
              : () {
                  _fabKey.currentState?.toggle();
                  _openImport(context);
                },
        ),
      ],
    );
  }
}

// ── FAB action child ──────────────────────────────────────────────────────────

class _FabAction extends StatelessWidget {
  static const _buttonSize = 52.0;

  final IconData icon;
  final String label;
  final Color color;
  final String? lottieAsset;
  final double? lottieSize;
  final VoidCallback? onTap;

  const _FabAction({
    required this.icon,
    required this.label,
    required this.color,
    this.lottieAsset,
    this.lottieSize,
    this.onTap,
  });

  static Future<LottieComposition?> _dotLottieDecoder(List<int> bytes) {
    return LottieComposition.decodeZip(
      bytes,
      filePicker: (files) => files.firstWhere(
        (f) =>
            f.name.startsWith('animations/') && f.name.endsWith('.json'),
        orElse: () => files.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDotLottie = lottieAsset?.endsWith('.lottie') ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: lottieAsset != null
                  ? OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Lottie.asset(
                        lottieAsset!,
                        width: lottieSize ?? _buttonSize,
                        height: lottieSize ?? _buttonSize,
                        fit: BoxFit.contain,
                        repeat: true,
                        decoder:
                            isDotLottie ? _dotLottieDecoder : null,
                        errorBuilder: (ctx, e, _) =>
                            Icon(icon, size: 28, color: color),
                      ),
                    )
                  : Icon(icon, size: 28, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Import info dialog (local — needs Scaffold context from this page) ─────────

Future<bool?> _showImportInfoDialogLocal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 10,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purple600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(CupertinoIcons.info,
                      color: AppColors.purple600, size: 15),
                ),
                const Text(
                  'Heads up',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
                height: 1, thickness: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            const Text(
              "For your privacy, this app requests only minimal Google Drive "
              "access — so it can see only the forms it created here. Forms "
              "made on the Google Forms website or in other apps don't show "
              "up automatically. Tap below to browse your Drive and pick the "
              "ones to import.",
              style: TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.ink2),
            ),
            const SizedBox(height: 20),
            _ImportDialogButton(
              label: 'Import Existing Forms',
              filled: true,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 10),
            _ImportDialogButton(
              label: 'Later',
              filled: false,
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ImportDialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ImportDialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? AppColors.purple600 : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: filled ? AppShapes.primaryButtonShadow : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
