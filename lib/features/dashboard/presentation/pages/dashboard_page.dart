import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../../core/widgets/skeleton_bone.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';

const _purple = Color(0xFF772FC0);

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
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context, state),
          drawer: _buildDrawer(context),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton(
            onPressed: isCreating ? null : () => _onNewForm(context),
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            elevation: 4,
            child: isCreating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.add, size: 28),
          ),
        );
      },
    );
  }

  void _onNewForm(BuildContext context) async {
    final name = await _showCreateDialog(context);
    if (name == null || !context.mounted) return;
    final cubit = context.read<DashboardCubit>();
    try {
      await cubit.createForm(title: name.isEmpty ? 'Untitled form' : name);
    } catch (_) {
      if (!context.mounted) return;
      ErrorModal.show(
        context,
        title: "Couldn't create form.",
        body: 'Check your connection and try again.',
        secondaryLabel: 'Cancel',
        onSecondary: () {},
        primaryLabel: 'Retry',
        onPrimary: () => _onNewForm(context),
      );
    }
  }

  Future<String?> _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please enter form name',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter form name',
                  filled: true,
                  fillColor: const Color(0xFFF3F0FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Create',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
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
    if (context.mounted) {
      context.read<DashboardCubit>().loadForms();
    }
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, DashboardState state) {
    if (_searchOpen) {
      return AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _searchOpen = false);
            _searchController.clear();
            context.read<DashboardCubit>().loadForms();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search forms…',
            border: InputBorder.none,
          ),
          onChanged: (q) => context.read<DashboardCubit>().search(q),
        ),
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          icon: SvgPicture.asset('assets/dashboard_hamburger.svg',
              width: 24, height: 24),
        ),
      ),
      title: const Text(
        'Form list',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black54),
          onPressed: () => setState(() => _searchOpen = true),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).pop();
                context.read<SignInCubit>().signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DashboardState state) {
    return switch (state) {
      DashboardInitial() || DashboardLoading() => const _DashboardSkeleton(),
      DashboardLoaded(:final forms, :final query, :final isShowingCache) =>
        Column(
          children: [
            if (isShowingCache) const _CacheBanner(),
            Expanded(child: _FormList(forms: forms, query: query)),
          ],
        ),
      DashboardError(:final message, :final cachedForms) =>
        cachedForms != null
            ? Column(
                children: [
                  _InlineBanner(message: message),
                  Expanded(child: _FormList(forms: cachedForms, query: '')),
                ],
              )
            : _FullScreenError(
                message: message,
                onRetry: () => context.read<DashboardCubit>().refresh(),
              ),
    };
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEEEEEE),
      highlightColor: const Color(0xFFFAFAFA),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SkeletonBone(width: 44, height: 56, radius: 6),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBone(width: double.infinity, height: 14, radius: 4),
                SizedBox(height: 8),
                SkeletonBone(width: 120, height: 11, radius: 4),
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
      onRefresh: () => context.read<DashboardCubit>().refresh(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          MediaQuery.viewPaddingOf(context).bottom + 80,
        ),
        itemCount: forms.length,
        itemBuilder: (context, i) => _FormCard(form: forms[i]),
      ),
    );
  }
}

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
              width: 200,
            ),
            const SizedBox(height: 32),
            const Text(
              'No forms yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Forms you create here will appear in this list.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
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
            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 20),
            Text(
              'No forms match "$query".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search term.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final FormEntry form;

  const _FormCard({required this.form});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openForm(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SvgPicture.asset('assets/dashboard_form_icon.svg',
                  width: 44, height: 56),
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      form.modifiedTime != null
                          ? _formatDate(form.modifiedTime!)
                          : '',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_RowAction>(
                onSelected: (action) => _handleAction(context, action),
                icon: const Icon(Icons.more_vert, color: Colors.black45),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _RowAction.open, child: Text('Open')),
                  PopupMenuItem(
                      value: _RowAction.delete, child: Text('Delete')),
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
      builder: (_) => EditorPage(formId: form.id, formName: form.name),
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

// ── Error / Banner widgets ────────────────────────────────────────────────────

class _FullScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullScreenError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _purple),
              child: const Text('Retry'),
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
      color: Colors.orange[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        message,
        style: TextStyle(color: Colors.orange[900], fontSize: 13),
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
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Showing cached list',
        style: TextStyle(color: Colors.blue[900], fontSize: 13),
      ),
    );
  }
}
