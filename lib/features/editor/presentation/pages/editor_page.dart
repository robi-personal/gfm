import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/form_settings.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/widgets/skeleton_bone.dart';
import '../widgets/question_edit_sheet.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../preview/preview_screen.dart';
import '../../../responses/responses_screen.dart';
import '../cubit/editor_cubit.dart';
import '../widgets/form_header_card.dart';
import '../widgets/question_card.dart';
import '../widgets/section_card.dart';

const _purple = Color(0xFF772FC0);

class EditorPage extends StatelessWidget {
  final String formId;
  final String formName;

  const EditorPage({
    super.key,
    required this.formId,
    required this.formName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EditorCubit>()..loadForm(formId),
      child: _EditorView(formId: formId, initialName: formName),
    );
  }
}

// ── Main view (stateful for TabController) ────────────────────────────────────

class _EditorView extends StatefulWidget {
  final String formId;
  final String initialName;

  const _EditorView({required this.formId, required this.initialName});

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    // Intercept Responses tab: navigate instead of switching tabs
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      _tabController.animateTo(0, duration: Duration.zero);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openResponses());
    }
  }

  void _openResponses() {
    final state = context.read<EditorCubit>().state;
    if (state is! EditorLoaded) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ResponsesScreen(
        formId: widget.formId,
        formTitle: state.form.info.title,
        items: state.form.items,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorCubit, EditorState>(
      listener: _onStateChange,
      listenWhen: (prev, curr) {
        if (prev.runtimeType != curr.runtimeType) return true;
        if (curr is EditorLoaded) {
          final p = prev is EditorLoaded ? prev : null;
          if (curr.conflictPending && !(p?.conflictPending ?? false)) return true;
          if (curr.saveFailed && !(p?.saveFailed ?? false)) return true;
          if (curr.pendingEditItemId != null &&
              curr.pendingEditItemId != (p?.pendingEditItemId)) {
            return true;
          }
        }
        return curr is EditorError;
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            // Action strip: Preview | Share | Save
            _ActionStrip(formId: widget.formId),
            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: _purple,
              indicatorColor: _purple,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Questions'),
                Tab(text: 'Responses'),
                Tab(text: 'Settings'),
              ],
            ),
            // Tab content area
            Expanded(
              child: BlocBuilder<EditorCubit, EditorState>(
                buildWhen: (prev, curr) {
                  if (prev.runtimeType != curr.runtimeType) return true;
                  if (prev is EditorLoaded && curr is EditorLoaded) {
                    return prev.isSaving != curr.isSaving;
                  }
                  return false;
                },
                builder: (context, state) => switch (state) {
                  EditorLoading() => const _EditorSkeleton(),
                  EditorLoaded(:final isSaving) when isSaving =>
                    const _EditorSkeleton(),
                  EditorError(:final kind, :final message)
                      when kind == EditorErrorKind.network =>
                    _FullScreenError(
                      message: message,
                      onRetry: () =>
                          context.read<EditorCubit>().loadForm(widget.formId),
                    ),
                  EditorError() => const SizedBox.shrink(),
                  EditorLoaded() => TabBarView(
                      controller: _tabController,
                      children: [
                        const _EditorBody(),
                        // Responses: intercepted by tab listener — never actually shown
                        const SizedBox.shrink(),
                        _SettingsTabPage(formId: widget.formId),
                      ],
                    ),
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index != 0) return const SizedBox.shrink();
            return BlocSelector<EditorCubit, EditorState, bool>(
              selector: (state) => state is EditorLoaded && !state.isSaving,
              builder: (context, enabled) =>
                  _BottomBar(enabled: enabled, formId: widget.formId),
            );
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Form list',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SvgPicture.asset(
            'assets/dashboard_premium.svg',
            width: 26,
            height: 26,
          ),
        ),
      ],
    );
  }

  void _onStateChange(BuildContext context, EditorState state) {
    // Auto-open edit sheet for newly added items
    if (state case EditorLoaded(:final pendingEditItemId?)) {
      final cubit = context.read<EditorCubit>();
      cubit.clearPendingEdit();
      final loaded = state;
      final item = loaded.form.items
          .where((i) => i.itemId == pendingEditItemId)
          .firstOrNull;
      if (item != null) {
        final sections = loaded.form.items
            .where((i) => i.content is PageBreakItemContent)
            .toList();
        QuestionEditSheet.show(
          context, item, sections,
          isQuiz: loaded.form.settings.quizSettings.isQuiz,
        );
      }
      return;
    }

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
        title: 'Failed to save',
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

// ── Action strip: Preview | Share | Save ─────────────────────────────────────

class _ActionStrip extends StatelessWidget {
  final String formId;

  const _ActionStrip({required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState,
        ({bool isLoaded, bool isDirty, bool isSaving, String responderUri, String title, List<Item> items})>(
      selector: (state) => state is EditorLoaded
          ? (
              isLoaded: true,
              isDirty: state.isDirty,
              isSaving: state.isSaving,
              responderUri: state.form.responderUri,
              title: state.form.info.title,
              items: state.form.items,
            )
          : (
              isLoaded: false,
              isDirty: false,
              isSaving: false,
              responderUri: '',
              title: '',
              items: const <Item>[],
            ),
      builder: (context, data) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StripButton(
                icon: Icons.visibility_outlined,
                label: 'Preview',
                enabled: data.isLoaded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PreviewScreen(
                      responderUri: data.responderUri,
                      formTitle: data.title,
                    ),
                  ),
                ),
              ),
              _StripButton(
                icon: Icons.share_outlined,
                label: 'Share',
                enabled: data.isLoaded,
                onTap: () => Share.share(data.responderUri, subject: data.title),
              ),
              _SaveStripButton(data: data),
            ],
          ),
        );
      },
    );
  }
}

class _StripButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _StripButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveStripButton extends StatelessWidget {
  final ({bool isLoaded, bool isDirty, bool isSaving, String responderUri, String title, List<Item> items}) data;

  const _SaveStripButton({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isSaving) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 2),
            Text('Save', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
    }

    final active = data.isLoaded && data.isDirty;
    final color = active ? _purple : Colors.grey;

    return InkWell(
      onTap: active
          ? () => context.read<EditorCubit>().save()
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              'Save',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Value objects for BlocSelectors ──────────────────────────────────────────

class _BodyData {
  final List<String> itemIds;
  final String title;
  final String description;

  const _BodyData({
    required this.itemIds,
    required this.title,
    required this.description,
  });

  static const empty = _BodyData(itemIds: [], title: '', description: '');

  @override
  bool operator ==(Object other) =>
      other is _BodyData &&
      other.title == title &&
      other.description == description &&
      listEquals(other.itemIds, itemIds);

  @override
  int get hashCode =>
      Object.hash(title, description, Object.hashAll(itemIds));
}

class _ItemData {
  final Item? item;
  final List<Item> sections;
  final bool isQuiz;

  const _ItemData({required this.item, required this.sections, this.isQuiz = false});

  @override
  bool operator ==(Object other) =>
      other is _ItemData &&
      other.item == item &&
      other.isQuiz == isQuiz &&
      listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(item, isQuiz, Object.hashAll(sections));
}

// ── Editor body (Questions tab) ───────────────────────────────────────────────

class _EditorBody extends StatelessWidget {
  const _EditorBody();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState, _BodyData>(
      selector: (state) {
        if (state is! EditorLoaded) return _BodyData.empty;
        final form = state.form;
        return _BodyData(
          itemIds: form.items.map((i) => i.itemId).toList(),
          title: form.info.title,
          description: form.info.description,
        );
      },
      builder: (context, data) {
        final header = FormHeaderCard(
          key: const ValueKey('__header__'),
          initialTitle: data.title,
          initialDescription: data.description,
        );

        const physics = BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );

        if (data.itemIds.isEmpty) {
          return CustomScrollView(
            physics: physics,
            slivers: [
              SliverToBoxAdapter(child: header),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No questions yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          physics: physics,
          cacheExtent: 600,
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 100),
              sliver: SliverReorderableList(
                itemCount: data.itemIds.length,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  if (oldIndex == newIndex) return;
                  context.read<EditorCubit>().moveItem(oldIndex, newIndex);
                },
                itemBuilder: (context, i) {
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(data.itemIds[i]),
                    index: i,
                    child: BlocProvider.value(
                      value: context.read<EditorCubit>(),
                      child: _ItemRow(itemId: data.itemIds[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Per-item row ──────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final String itemId;

  const _ItemRow({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState, _ItemData>(
      selector: (state) {
        if (state is! EditorLoaded) {
          return const _ItemData(item: null, sections: []);
        }
        final items = state.form.items;
        final idx = items.indexWhere((i) => i.itemId == itemId);
        final item = idx == -1 ? null : items[idx];
        final sections = items
            .where((i) => i.content is PageBreakItemContent)
            .toList(growable: false);
        return _ItemData(
          item: item,
          sections: sections,
          isQuiz: state.form.settings.quizSettings.isQuiz,
        );
      },
      builder: (context, data) {
        final item = data.item;
        if (item == null) return const SizedBox.shrink();
        return switch (item.content) {
          QuestionItemContent() || QuestionGroupItemContent() =>
            QuestionCard(item: item, sections: data.sections, isQuiz: data.isQuiz),
          PageBreakItemContent() => SectionCard(item: item),
          TextItemContent() => TextBlockCard(item: item),
          ImageItemContent() => _ImageCard(item: item),
          VideoItemContent() => _VideoCard(item: item),
        };
      },
    );
  }
}

// ── Settings tab page (inline) ────────────────────────────────────────────────

class _SettingsTabPage extends StatelessWidget {
  final String formId;

  const _SettingsTabPage({required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState, FormSettings?>(
      selector: (state) =>
          state is EditorLoaded ? state.form.settings : null,
      builder: (context, settings) {
        if (settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _SettingsContent(
          initialSettings: settings,
          formId: formId,
        );
      },
    );
  }
}

class _SettingsContent extends StatefulWidget {
  final FormSettings initialSettings;
  final String formId;

  const _SettingsContent({
    required this.initialSettings,
    required this.formId,
  });

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late EmailCollectionType _emailType;
  late bool _isQuiz;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailType = widget.initialSettings.emailCollectionType;
    _isQuiz = widget.initialSettings.quizSettings.isQuiz;
  }

  Future<void> _save({required EmailCollectionType emailType, required bool isQuiz}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await context.read<EditorCubit>().updateSettings(
          FormSettings(
            quizSettings: QuizSettings(isQuiz: isQuiz),
            emailCollectionType: emailType,
          ),
        );
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _onQuizToggle(bool value) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn off quiz mode?'),
          content: const Text(
            'All answer keys and point values will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Turn off'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _isQuiz = value);
    await _save(emailType: _emailType, isQuiz: value);
  }

  Future<void> _onEmailTypeChange(EmailCollectionType value) async {
    setState(() => _emailType = value);
    await _save(emailType: value, isQuiz: _isQuiz);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email collection
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Collect email addresses',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          RadioGroup<EmailCollectionType>(
            groupValue: _emailType,
            onChanged: _isSaving
                ? (_) {}
                : (v) => _onEmailTypeChange(v as EmailCollectionType),
            child: Column(
              children: [
                RadioListTile<EmailCollectionType>(
                  title: const Text("Don't collect"),
                  value: EmailCollectionType.doNotCollect,
                ),
                RadioListTile<EmailCollectionType>(
                  title: const Text('Verified (Workspace accounts only)'),
                  value: EmailCollectionType.verified,
                ),
                RadioListTile<EmailCollectionType>(
                  title: const Text('Ask respondents'),
                  value: EmailCollectionType.responderInput,
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          // Quiz mode
          SwitchListTile(
            title: const Text('Quiz mode'),
            subtitle: const Text('Assign point values and set correct answers'),
            value: _isQuiz,
            onChanged: _isSaving ? null : _onQuizToggle,
          ),
        ],
      ),
    );
  }
}

// ── Bottom bar (5 buttons) ────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final String formId;

  const _BottomBar({required this.enabled, required this.formId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<EditorCubit>();
    final state = cubit.state;
    final responderUri =
        state is EditorLoaded ? state.form.responderUri : '';
    final formTitle =
        state is EditorLoaded ? state.form.info.title : '';

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Add question
            _BarButton(
              icon: Icons.add,
              tooltip: 'Add question',
              enabled: enabled,
              onTap: () => cubit.addQuestion(),
            ),
            // Add image (placeholder — no API support yet)
            _BarButton(
              icon: Icons.image_outlined,
              tooltip: 'Add image',
              enabled: false,
              onTap: null,
            ),
            // Add text block
            _BarButton(
              icon: Icons.text_fields,
              tooltip: 'Add text block',
              enabled: enabled,
              onTap: () => cubit.addTextBlock(),
            ),
            // Preview
            _BarButton(
              icon: Icons.play_arrow_outlined,
              tooltip: 'Preview',
              enabled: enabled,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PreviewScreen(
                    responderUri: responderUri,
                    formTitle: formTitle,
                  ),
                ),
              ),
            ),
            // Add section
            _BarButton(
              icon: Icons.view_agenda_outlined,
              tooltip: 'Add section',
              enabled: enabled,
              onTap: () => cubit.addSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onTap;

  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _SkeletonHeaderCard(),
          SizedBox(height: 8),
          _SkeletonQuestionCard(),
          _SkeletonQuestionCard(),
          _SkeletonQuestionCard(),
        ],
      ),
    );
  }
}

class _SkeletonHeaderCard extends StatelessWidget {
  const _SkeletonHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBone(width: 200, height: 20, radius: 4),
            SizedBox(height: 10),
            SkeletonBone(width: double.infinity, height: 13, radius: 4),
          ],
        ),
      ),
    );
  }
}

class _SkeletonQuestionCard extends StatelessWidget {
  const _SkeletonQuestionCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBone(width: 180, height: 14, radius: 4),
            SizedBox(height: 10),
            SkeletonBone(width: 72, height: 22, radius: 12),
            SizedBox(height: 12),
            SkeletonBone(width: double.infinity, height: 11, radius: 4),
            SizedBox(height: 6),
            SkeletonBone(width: 160, height: 11, radius: 4),
          ],
        ),
      ),
    );
  }
}

// ── Media placeholders ────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final Item item;

  const _ImageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            if (item.title?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.title!,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final Item item;

  const _VideoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final content = item.content as VideoItemContent;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.red.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline,
                size: 40, color: Colors.red.shade400),
            const SizedBox(height: 4),
            if (content.caption?.isNotEmpty == true)
              Text(content.caption!,
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Full screen error ────────────────────────────────────────────────────────

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
