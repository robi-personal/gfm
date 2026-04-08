import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/auth_cubit.dart';
import '../../core/di/injection.dart';
import '../../core/models/drive_form_entry.dart';
import '../../core/widgets/error_modal.dart';
import '../form_detail/form_detail_screen.dart';
import 'dashboard_cubit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit(getIt(), getIt())..loadForms(),
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
        // Only listen when createNav is newly set.
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
          appBar: _buildAppBar(context, state),
          body: _buildBody(context, state),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isCreating ? null : () => _onNewForm(context),
            icon: isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add),
            label: Text(isCreating ? 'Creating…' : 'New form'),
          ),
        );
      },
    );
  }

  void _onNewForm(BuildContext context) async {
    final cubit = context.read<DashboardCubit>();
    try {
      await cubit.createForm();
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

  void _handleCreateNavigation(
      BuildContext context, CreateNavigation nav) async {
    final cubit = context.read<DashboardCubit>();
    cubit.clearNavigation();

    if (nav.publishFailed && context.mounted) {
      // Show the modal first; navigate either way on button tap.
      ErrorModal.show(
        context,
        title: 'Form created but not published.',
        body: "Responders can't submit until it's published. Publish now?",
        secondaryLabel: 'Later',
        onSecondary: () => _navigateToForm(context, nav),
        primaryLabel: 'Publish',
        onPrimary: () {
          _navigateToForm(context, nav);
          // TODO(step-6): trigger publish from editor save-pill
        },
      );
      return;
    }

    _navigateToForm(context, nav);
  }

  void _navigateToForm(BuildContext context, CreateNavigation nav) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FormDetailScreen(
        formId: nav.formId,
        formName: nav.formName,
      ),
    ));
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, DashboardState state) {
    final sortOrder = switch (state) {
      DashboardLoaded(:final sortOrder) => sortOrder,
      DashboardError(:final sortOrder) => sortOrder,
      _ => SortOrder.modifiedDesc,
    };

    if (_searchOpen) {
      return AppBar(
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
      title: const Text('My Forms'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _searchOpen = true),
        ),
        IconButton(
          tooltip: sortOrder == SortOrder.modifiedDesc
              ? 'Sort by created'
              : 'Sort by modified',
          icon: Icon(
            sortOrder == SortOrder.modifiedDesc
                ? Icons.schedule
                : Icons.add_circle_outline,
          ),
          onPressed: () => context.read<DashboardCubit>().toggleSort(),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => context.read<AuthCubit>().signOut(),
        ),
      ],
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, DashboardState state) {
    return switch (state) {
      DashboardInitial() || DashboardLoading() =>
        const Center(child: CircularProgressIndicator()),
      DashboardLoaded(:final forms, :final isShowingCache) => Column(
          children: [
            if (isShowingCache) const _CacheBanner(),
            Expanded(child: _FormList(forms: forms)),
          ],
        ),
      DashboardError(:final message, :final cachedForms) =>
        cachedForms != null
            ? Column(
                children: [
                  _InlineBanner(message: message),
                  Expanded(child: _FormList(forms: cachedForms)),
                ],
              )
            : _FullScreenError(
                message: message,
                onRetry: () => context.read<DashboardCubit>().refresh(),
              ),
    };
  }
}

// ── Form list ─────────────────────────────────────────────────────────────────

class _FormList extends StatelessWidget {
  final List<DriveFormEntry> forms;

  const _FormList({required this.forms});

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No forms yet.\n\nForms you create here will appear in this list. '
            'To add an existing form, paste its link.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().refresh(),
      child: ListView.separated(
        itemCount: forms.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) => _FormRow(form: forms[i]),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final DriveFormEntry form;

  const _FormRow({required this.form});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(form.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: form.modifiedTime != null
          ? Text(_formatDate(form.modifiedTime!))
          : null,
      onTap: () => _openForm(context),
      trailing: PopupMenuButton<_RowAction>(
        onSelected: (action) => _handleAction(context, action),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _RowAction.open, child: Text('Open')),
          PopupMenuItem(value: _RowAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          FormDetailScreen(formId: form.id, formName: form.name),
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
              body: "It's still in your list. Try again?",
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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
