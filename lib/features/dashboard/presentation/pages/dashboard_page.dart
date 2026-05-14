import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../../core/widgets/skeleton_bone.dart';
import '../../../ai_form_builder/presentation/pages/ai_form_builder_page.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';
import 'template_picker_page.dart';
import '../../../../core/theme/app_colors.dart';

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
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(context, state),
          drawer: _buildDrawer(context),
          body: _buildBody(context, state),
          floatingActionButtonLocation: ExpandableFab.location,
          floatingActionButton: _buildFab(context, isCreating),
        );
      },
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  final _fabKey = GlobalKey<ExpandableFabState>();

  Widget _buildFab(BuildContext context, bool isCreating) {
    return ExpandableFab(
      key: _fabKey,
      type: ExpandableFabType.up,
      distance: 75,
      duration: const Duration(milliseconds: 220),
      overlayStyle: ExpandableFabOverlayStyle(
        color: Colors.black.withValues(alpha: 0.45),
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

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, DashboardState state) {
    if (_searchOpen) {
      return AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.purple),
          onPressed: () {
            setState(() => _searchOpen = false);
            _searchController.clear();
            context.read<DashboardCubit>().search('');
          },
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          style: const TextStyle(
              fontSize: 15, color: AppColors.textPrimary),
          cursorColor: AppColors.purple,
          decoration: InputDecoration(
            hintText: 'Search forms…',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.purple, width: 1.5),
            ),
          ),
          onChanged: (q) =>
              context.read<DashboardCubit>().search(q),
        ),
      );
    }

    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          icon: SvgPicture.asset(
            'assets/dashboard_hamburger.svg',
            width: 24,
            height: 24,
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/app_logo.png', width: 28, height: 28),
          const SizedBox(width: 8),
          const Text(
            'GFM',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 22),
          onPressed: () {
            setState(() => _searchOpen = true);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _searchFocus.requestFocus(),
            );
          },
        ),
        FutureBuilder<bool>(
          future: getIt<GetUserStatus>()
              .call(const NoParams())
              .then((r) => r.fold((_) => false, (s) => s.isPremium)),
          builder: (context, snapshot) {
            if (snapshot.data != false) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => PaywallPage.show(context),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SvgPicture.asset(
                  'assets/dashboard_premium.svg',
                  width: 26,
                  height: 26,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purpleMid, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 28,
              left: 20,
              right: 20,
            ),
            child: BlocSelector<SignInCubit, SignInState,
                ({String? displayName, String? photoUrl, String email})>(
              selector: (state) => state is Authenticated
                  ? (
                      displayName: state.user.displayName,
                      photoUrl: state.user.photoUrl,
                      email: state.user.email,
                    )
                  : (displayName: null, photoUrl: null, email: ''),
              builder: (context, user) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _UserAvatar(
                      photoUrl: user.photoUrl,
                      displayName: user.displayName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.displayName != null)
                            Text(
                              user.displayName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (user.email.isNotEmpty)
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                _DrawerSection(
                  label: 'CREATE',
                  items: [
                    _DrawerItem(
                      icon: Icons.auto_awesome_rounded,
                      title: 'AI Form Builder',
                      onTap: () {
                        Navigator.of(context).pop();
                        _openAiBuilder(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.edit_note_rounded,
                      title: 'Create Form',
                      onTap: () {
                        Navigator.of(context).pop();
                        _onNewForm(context);
                      },
                    ),
                    _DrawerItem(
                      icon: CupertinoIcons.link,
                      title: 'Import Form',
                      onTap: () {
                        Navigator.of(context).pop();
                        _openImport(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DrawerSection(
                  label: 'SUBSCRIPTION',
                  items: [
                    _DrawerItem(
                      assetIcon: 'assets/upgrade_to_premium.png',
                      title: 'Upgrade Plan',
                      onTap: () {
                        Navigator.of(context).pop();
                        PaywallPage.show(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DrawerSection(
                  label: 'SUPPORT US',
                  items: [
                    _DrawerItem(
                      assetIcon: 'assets/nav_share.png',
                      title: 'Share on the App Store',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _DrawerItem(
                      assetIcon: 'assets/rate_us.png',
                      title: 'Rate the app',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DrawerSection(
                  label: 'LEGAL',
                  items: [
                    _DrawerItem(
                      icon: CupertinoIcons.lock_shield,
                      title: 'Privacy Policy',
                      onTap: () {
                        Navigator.of(context).pop();
                        launchUrl(
                          Uri.parse('https://gformmanager.netlify.app/privacy'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: CupertinoIcons.doc_text,
                      title: 'Terms of Use',
                      onTap: () {
                        Navigator.of(context).pop();
                        launchUrl(
                          Uri.parse('https://gformmanager.netlify.app/terms'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DrawerSection(
                  label: 'ACCOUNT',
                  labelColor: Colors.red,
                  items: [
                    _DrawerItem(
                      assetIcon: 'assets/logout.png',
                      assetColor: Colors.red,
                      title: 'Sign out',
                      textColor: Colors.red,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.read<SignInCubit>().signOut();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, DashboardState state) {
    return switch (state) {
      DashboardInitial() ||
      DashboardLoading() =>
        const _DashboardSkeleton(),
      DashboardLoaded(
        :final forms,
        :final query,
        :final isShowingCache,
        :final sortOrder,
        :final renamingId,
      ) =>
        Column(
          children: [
            if (isShowingCache) const _CacheBanner(),
            _SubHeader(
              count: forms.length,
              query: query,
              sortOrder: sortOrder,
              onSort: () =>
                  context.read<DashboardCubit>().toggleSort(),
            ),
            Expanded(
              child: _FormList(
                forms: forms,
                query: query,
                renamingId: renamingId,
              ),
            ),
          ],
        ),
      DashboardError(:final message, :final cachedForms) =>
        cachedForms != null
            ? Column(
                children: [
                  _InlineBanner(message: message),
                  Expanded(
                      child:
                          _FormList(forms: cachedForms, query: '')),
                ],
              )
            : _FullScreenError(
                message: message,
                onRetry: () =>
                    context.read<DashboardCubit>().refresh(),
              ),
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
    await showImportFormDialog(context, context.read<DashboardCubit>());
  }

  Future<void> _openAiBuilder(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const AiFormBuilderPage(),
    ));
    if (context.mounted) {
      context.read<DashboardCubit>().loadForms();
    }
  }

  void _handleCreateNavigation(
      BuildContext context, CreateNavigation nav) async {
    final cubit = context.read<DashboardCubit>();
    cubit.clearNavigation();

    if (nav.publishFailed && context.mounted) {
      ErrorModal.show(
        context,
        title: 'Form created but not published.',
        body:
            "Responders can't submit until it's published. Publish now?",
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
    if (context.mounted) {
      context.read<DashboardCubit>().loadForms();
    }
  }
}

// ── FAB action child ─────────────────────────────────────────────────────────

class _FabAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? lottieAsset;
  final double buttonSize;
  final double? lottieSize;
  final VoidCallback? onTap;

  const _FabAction({
    required this.icon,
    required this.label,
    required this.color,
    this.lottieAsset,
    this.buttonSize = 52, // ignore: unused_element_parameter
    this.lottieSize,
    this.onTap,
  });

  static Future<LottieComposition?> _dotLottieDecoder(
      List<int> bytes) {
    return LottieComposition.decodeZip(
      bytes,
      filePicker: (files) => files.firstWhere(
        (f) =>
            f.name.startsWith('animations/') &&
            f.name.endsWith('.json'),
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
          // Label pill
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
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
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: buttonSize,
              height: buttonSize,
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
                          width: lottieSize ?? buttonSize,
                          height: lottieSize ?? buttonSize,
                          fit: BoxFit.contain,
                          repeat: true,
                          decoder: isDotLottie ? _dotLottieDecoder : null,
                          errorBuilder: (context, error, stack) {
                            debugPrint('Lottie error: $error');
                            return Icon(icon, size: 28, color: color);
                          },
                        ),
                      )
                    : Icon(icon, size: 28, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-header ────────────────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  final int count;
  final String query;
  final SortOrder sortOrder;
  final VoidCallback onSort;

  const _SubHeader({
    required this.count,
    required this.query,
    required this.sortOrder,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(
            count == 1 ? '1 form' : '$count forms',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSort,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.arrow_up_arrow_down,
                      size: 12, color: AppColors.purple),
                  const SizedBox(width: 5),
                  Text(
                    sortOrder == SortOrder.modifiedDesc
                        ? 'Last modified'
                        : 'Date created',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.groupedBackground,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: 6,
        itemBuilder: (context, i) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SkeletonBone(width: 44, height: 56, radius: 8),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBone(
                    width: double.infinity, height: 13, radius: 4),
                SizedBox(height: 8),
                SkeletonBone(width: 100, height: 11, radius: 4),
              ],
            ),
          ),
          SizedBox(width: 14),
          SkeletonBone(width: 20, height: 20, radius: 4),
        ],
      ),
    );
  }
}

// ── Form list ─────────────────────────────────────────────────────────────────

class _FormList extends StatelessWidget {
  final List<FormEntry> forms;
  final String query;
  final String? renamingId;

  const _FormList({
    required this.forms,
    required this.query,
    this.renamingId,
  });

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return query.isNotEmpty
          ? _SearchEmptyState(query: query)
          : const _EmptyState();
    }

    return RefreshIndicator(
      color: AppColors.purple,
      onRefresh: () => context.read<DashboardCubit>().refresh(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 90,
        ),
        itemCount: forms.length,
        itemBuilder: (_, i) => _FormCard(
          form: forms[i],
          isRenaming: forms[i].id == renamingId,
        ),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/dashboard_no_form_banner.svg',
                  width: 180,
                ),
                const SizedBox(height: 28),
                const Text(
                  'No forms yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap "New Form" to get started,\nor use AI to build one instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(CupertinoIcons.info_circle,
                          size: 15,
                          color: AppColors.purple.withValues(alpha: 0.70)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Forms created on Google Forms web won\'t appear here automatically. Use the Import Form button to add them.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.purple,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  final String query;
  const _SearchEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.search,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 20),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different search term.',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final FormEntry form;
  final bool isRenaming;

  const _FormCard({required this.form, this.isRenaming = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openForm(context),
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.purple.withValues(alpha: 0.06),
        highlightColor: AppColors.purple.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/dashboard_form_icon.svg',
                width: 26,
                height: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (!form.isOwned) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Imported',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (form.modifiedTime != null)
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.clock,
                            size: 11,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(form.modifiedTime!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (isRenaming)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CupertinoActivityIndicator(
                      radius: 10, color: AppColors.purple),
                )
              else
                PopupMenuButton<_RowAction>(
                  onSelected: (a) => _handleAction(context, a),
                  icon: const Icon(
                    CupertinoIcons.ellipsis,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _RowAction.open,
                      child: Row(children: [
                        Icon(CupertinoIcons.arrow_up_right_square,
                            size: 16, color: AppColors.textDark),
                        SizedBox(width: 10),
                        Text('Open'),
                      ]),
                    ),
                    if (form.isOwned)
                      const PopupMenuItem(
                        value: _RowAction.rename,
                        child: Row(children: [
                          Icon(CupertinoIcons.pencil,
                              size: 16, color: AppColors.textDark),
                          SizedBox(width: 10),
                          Text('Rename'),
                        ]),
                      ),
                    if (form.isOwned)
                      const PopupMenuItem(
                        value: _RowAction.delete,
                        child: Row(children: [
                          Icon(CupertinoIcons.trash,
                              size: 16, color: AppColors.error),
                          SizedBox(width: 10),
                          Text('Delete',
                              style:
                                  TextStyle(color: AppColors.error)),
                        ]),
                      )
                    else
                      const PopupMenuItem(
                        value: _RowAction.removeImport,
                        child: Row(children: [
                          Icon(CupertinoIcons.minus_circle,
                              size: 16, color: AppColors.error),
                          SizedBox(width: 10),
                          Text('Remove from list',
                              style:
                                  TextStyle(color: AppColors.error)),
                        ]),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EditorPage(formId: form.id, formName: form.name),
    ));
  }

  void _handleAction(BuildContext context, _RowAction action) {
    switch (action) {
      case _RowAction.open:
        _openForm(context);
      case _RowAction.rename:
        _renameForm(context);
      case _RowAction.delete:
        _confirmDelete(context);
      case _RowAction.removeImport:
        _removeImport(context);
    }
  }

  void _removeImport(BuildContext context) {
    ErrorModal.show(
      context,
      title: 'Remove from list?',
      body: 'This will remove "${form.name}" from your imported list. The original form won\'t be affected.',
      secondaryLabel: 'Cancel',
      onSecondary: () {},
      primaryLabel: 'Remove',
      onPrimary: () async {
        try {
          await context.read<DashboardCubit>().removeImportedForm(form.id);
        } catch (_) {
          if (!context.mounted) return;
          ErrorModal.show(
            context,
            title: "Couldn't remove form.",
            body: 'Check your connection and try again.',
            secondaryLabel: 'Cancel',
            onSecondary: () {},
            primaryLabel: 'Retry',
            onPrimary: () => _removeImport(context),
          );
        }
      },
    );
  }

  void _renameForm(BuildContext context) async {
    final name = await _showRenameDialog(context, current: form.name);
    if (name == null || !context.mounted) return;
    try {
      await context.read<DashboardCubit>().renameForm(form.id, name);
    } catch (_) {
      if (!context.mounted) return;
      ErrorModal.show(
        context,
        title: "Couldn't rename form.",
        body: 'Check your connection and try again.',
        secondaryLabel: 'Cancel',
        onSecondary: () {},
        primaryLabel: 'Retry',
        onPrimary: () => _renameForm(context),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    ErrorModal.show(
      context,
      title: 'Delete this form?',
      body: 'It will be moved to trash in your Google Drive.',
      secondaryLabel: 'Cancel',
      onSecondary: () {},
      primaryLabel: 'Delete',
      onPrimary: () async {
        try {
          await cubit.deleteForm(form.id);
        } catch (_) {
          if (context.mounted) {
            ErrorModal.show(
              context,
              title: "Couldn't delete this form.",
              body: "It's still in your list.",
              secondaryLabel: 'Cancel',
              onSecondary: () {},
              primaryLabel: 'Retry',
              onPrimary: () => cubit.deleteForm(form.id),
            );
          }
        }
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

enum _RowAction { open, rename, delete, removeImport }

String? _parseFormId(String input) {
  final trimmed = input.trim();
  // Full URL: https://docs.google.com/forms/d/{id}/edit  or /viewform
  final urlMatch = RegExp(r'/forms/d/([a-zA-Z0-9_-]+)').firstMatch(trimmed);
  if (urlMatch != null) return urlMatch.group(1);
  // Raw ID — alphanumeric + dash/underscore, reasonable length
  if (RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(trimmed)) return trimmed;
  return null;
}

Future<void> showImportFormDialog(
    BuildContext context, DashboardCubit cubit) async {
  final controller = TextEditingController();
  const green = AppColors.purple;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      String? errorText;
      bool isLoading = false;

      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> onImport() async {
            final formId = _parseFormId(controller.text);
            if (formId == null) {
              setState(
                  () => errorText = 'Paste a valid Google Form URL or ID.');
              return;
            }

            setState(() {
              isLoading = true;
              errorText = null;
            });

            try {
              await cubit.importForm(formId);
              if (ctx.mounted) Navigator.of(ctx).pop();
            } catch (e) {
              setState(() {
                isLoading = false;
                errorText = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(CupertinoIcons.link,
                            color: green, size: 15),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Import Form',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.groupedBackground),
                  const SizedBox(height: 12),
                  const Text(
                    'Paste a Google Form URL or form ID.',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF6E6E73)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary),
                    cursorColor: green,
                    decoration: InputDecoration(
                      hintText:
                          'https://docs.google.com/forms/d/…',
                      hintStyle: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.groupedBackground,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                      errorText: errorText,
                      errorMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: green, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.error, width: 1.5),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.error, width: 1.5),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setState(() => errorText = null);
                      }
                    },
                    onSubmitted: (_) => onImport(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.groupedBackground,
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: isLoading ? null : onImport,
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                            decoration: BoxDecoration(
                              color: green,
                              borderRadius:
                                  BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: green.withValues(
                                      alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isLoading
                                  ? const CupertinoActivityIndicator(
                                      radius: 9,
                                      color: Colors.white)
                                  : const Text(
                                      'Import',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> _showRenameDialog(BuildContext context,
    {required String current}) {
  final controller = TextEditingController(text: current);
  controller.selection =
      TextSelection(baseOffset: 0, extentOffset: current.length);

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.pencil,
                    color: AppColors.purple,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Rename Form',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: AppColors.groupedBackground),
            const SizedBox(height: 12),
            const Text(
              'Enter a new name for your form.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              cursorColor: AppColors.purple,
              decoration: InputDecoration(
                hintText: 'Form name',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.groupedBackground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.purple, width: 1.5),
                ),
              ),
              onSubmitted: (v) {
                final name = v.trim();
                if (name.isNotEmpty) Navigator.of(ctx).pop(name);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.groupedBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatefulBuilder(
                    builder: (ctx2, setLocal) {
                      controller.addListener(() => setLocal(() {}));
                      final canSave = controller.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: canSave
                            ? () =>
                                Navigator.of(ctx).pop(controller.text.trim())
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: canSave
                                ? AppColors.purple
                                : AppColors.purple.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: canSave
                                ? [
                                    BoxShadow(
                                      color: AppColors.purple.withValues(alpha: 0.30),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: const Center(
                            child: Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Error / banner widgets ────────────────────────────────────────────────────

class _FullScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullScreenError(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_slash,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.refresh,
                        size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  final String message;

  const _InlineBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF9EC),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              size: 15, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFF7D4E00), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF4FF),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(CupertinoIcons.cloud_download,
              size: 15, color: Color(0xFF0A84FF)),
          const SizedBox(width: 8),
          Text(
            'Showing cached list',
            style: const TextStyle(
                color: Color(0xFF0A58CA), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Drawer user avatar ────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;

  const _UserAvatar({this.photoUrl, this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial = (displayName?.isNotEmpty == true
            ? displayName![0]
            : null) ??
        '?';

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white.withValues(alpha: 0.20),
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (e, _) {},
        child: null,
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white.withValues(alpha: 0.20),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Drawer widgets ────────────────────────────────────────────────────────────

class _DrawerSection extends StatelessWidget {
  final String label;
  final Color labelColor;
  final List<_DrawerItem> items;

  const _DrawerSection({
    required this.label,
    required this.items,
    this.labelColor = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.groupedBackground,
                    indent: 50,
                    endIndent: 0,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String title;
  final String? assetIcon;
  final IconData? icon;
  final Color assetColor;
  final Color textColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.title,
    required this.onTap,
    this.assetIcon,
    this.icon,
    this.assetColor = AppColors.textDark,
    this.textColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: assetIcon != null
                  ? Image.asset(assetIcon!,
                      width: 20, height: 20, color: assetColor)
                  : icon != null
                      ? Icon(icon,
                          size: 20, color: AppColors.textDark)
                      : const SizedBox.shrink(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
