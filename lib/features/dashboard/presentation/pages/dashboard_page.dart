import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../../core/widgets/skeleton_bone.dart';
import '../../../ai_form_builder/presentation/pages/ai_form_builder_page.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';
import 'template_picker_page.dart';

// Exact same palette as ai_form_builder_page.dart
const _purple = Color(0xFF772FC0);
const _iosBg  = Colors.white;
const _cardBg = Colors.white;

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
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
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
          backgroundColor: _iosBg,
          appBar: _buildAppBar(context, state),
          drawer: _buildDrawer(context),
          body: _buildBody(context, state),
          floatingActionButton: _buildFab(context, isCreating),
        );
      },
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context, bool isCreating) {
    return GestureDetector(
      onLongPress: isCreating ? null : () => _openAiBuilder(context),
      child: GestureDetector(
        onTap: isCreating ? null : () => _onNewForm(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isCreating ? const Color(0xFFD1D1D6) : _purple,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isCreating
                ? []
                : [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isCreating
                  ? const CupertinoActivityIndicator(
                      radius: 9, color: Colors.white)
                  : const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                isCreating ? 'Creating…' : 'New Form',
                style: TextStyle(
                  color: isCreating
                      ? const Color(0xFF8E8E93)
                      : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, DashboardState state) {
    if (_searchOpen) {
      return AppBar(
        backgroundColor: _iosBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: _purple),
          onPressed: () {
            setState(() => _searchOpen = false);
            _searchController.clear();
            context.read<DashboardCubit>().loadForms();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(
              fontSize: 15, color: Color(0xFF1C1C1E)),
          cursorColor: _purple,
          decoration: InputDecoration(
            hintText: 'Search forms…',
            hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
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
                  const BorderSide(color: _purple, width: 1.5),
            ),
          ),
          onChanged: (q) =>
              context.read<DashboardCubit>().search(q),
        ),
      );
    }

    return AppBar(
      backgroundColor: _iosBg,
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
              color: Color(0xFF1C1C1E),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome_rounded,
              color: _purple, size: 22),
          tooltip: 'AI Form Builder',
          onPressed: () => _openAiBuilder(context),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded,
              color: Color(0xFF8E8E93), size: 22),
          onPressed: () => setState(() => _searchOpen = true),
        ),
        GestureDetector(
          onTap: () => PaywallPage.show(context),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SvgPicture.asset(
              'assets/dashboard_premium.svg',
              width: 26,
              height: 26,
            ),
          ),
        ),
      ],
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: _iosBg,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5418A0), _purple],
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Form list',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Google Forms Manager',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    PaywallPage.show(context);
                  },
                  child: SvgPicture.asset(
                    'assets/dashboard_premium.svg',
                    width: 28,
                    height: 28,
                  ),
                ),
              ],
            ),
          ),
          // Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                _DrawerSection(
                  label: 'SUBSCRIPTION',
                  items: [
                    _DrawerItem(
                      assetIcon: 'assets/upgrade_to_premium.png',
                      title: 'Upgrade to Premium',
                      onTap: () {
                        Navigator.of(context).pop();
                        PaywallPage.show(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                _DrawerSection(
                  label: 'FEEDBACK',
                  items: [
                    _DrawerItem(
                      icon: CupertinoIcons.mail,
                      title: 'Email us',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _DrawerSection(
                  label: 'LEGAL',
                  items: [
                    _DrawerItem(
                      icon: CupertinoIcons.lock_shield,
                      title: 'Privacy Policy',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    _DrawerItem(
                      icon: CupertinoIcons.doc_text,
                      title: 'Terms of Use',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
            Expanded(child: _FormList(forms: forms, query: query)),
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
              color: Color(0xFF8E8E93),
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
                color: _cardBg,
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
                      size: 12, color: _purple),
                  const SizedBox(width: 5),
                  Text(
                    sortOrder == SortOrder.modifiedDesc
                        ? 'Last modified'
                        : 'Date created',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _purple,
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
      baseColor: const Color(0xFFE5E5EA),
      highlightColor: const Color(0xFFF2F2F7),
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
        color: _cardBg,
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

  const _FormList({required this.forms, required this.query});

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return query.isNotEmpty
          ? _SearchEmptyState(query: query)
          : const _EmptyState();
    }

    return RefreshIndicator(
      color: _purple,
      onRefresh: () => context.read<DashboardCubit>().refresh(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.viewPaddingOf(context).bottom + 90,
        ),
        itemCount: forms.length,
        itemBuilder: (_, i) => _FormCard(form: forms[i]),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
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
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "New Form" to get started,\nor use AI to build one instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E93),
                height: 1.5,
              ),
            ),
          ],
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
                size: 48, color: const Color(0xFFC7C7CC)),
            const SizedBox(height: 20),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different search term.',
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF8E8E93)),
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

  const _FormCard({required this.form});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
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
        splashColor: _purple.withValues(alpha: 0.06),
        highlightColor: _purple.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/dashboard_form_icon.svg',
                width: 44,
                height: 56,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (form.modifiedTime != null)
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.clock,
                            size: 11,
                            color: Color(0xFFC7C7CC),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(form.modifiedTime!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_RowAction>(
                onSelected: (a) => _handleAction(context, a),
                icon: const Icon(
                  CupertinoIcons.ellipsis,
                  color: Color(0xFFC7C7CC),
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _RowAction.open,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.arrow_up_right_square,
                            size: 16, color: Color(0xFF3C3C43)),
                        SizedBox(width: 10),
                        Text('Open'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _RowAction.delete,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.trash,
                            size: 16, color: Color(0xFFFF3B30)),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(
                                color: Color(0xFFFF3B30))),
                      ],
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
      case _RowAction.delete:
        _confirmDelete(context);
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

enum _RowAction { open, delete }

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
                size: 48, color: Color(0xFFC7C7CC)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8E8E93),
                  height: 1.4),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.35),
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
              size: 15, color: Color(0xFFFF9500)),
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

// ── Drawer widgets ────────────────────────────────────────────────────────────

class _DrawerSection extends StatelessWidget {
  final String label;
  final Color labelColor;
  final List<_DrawerItem> items;

  const _DrawerSection({
    required this.label,
    required this.items,
    this.labelColor = const Color(0xFF8E8E93),
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
            color: _cardBg,
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
                    color: Color(0xFFF2F2F7),
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
    this.assetColor = const Color(0xFF3C3C43),
    this.textColor = const Color(0xFF1C1C1E),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: assetIcon != null
                  ? Image.asset(assetIcon!,
                      width: 20, height: 20, color: assetColor)
                  : icon != null
                      ? Icon(icon,
                          size: 20, color: const Color(0xFF3C3C43))
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
                size: 14, color: Color(0xFFC7C7CC)),
          ],
        ),
      ),
    );
  }
}
