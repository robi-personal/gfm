import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/models/item.dart';
import '../../core/models/item_content.dart';
import '../../core/widgets/error_modal.dart';
import 'editor_cubit.dart';
import 'widgets/form_header_card.dart';
import 'widgets/question_card.dart';
import 'widgets/section_card.dart';

class EditorScreen extends StatelessWidget {
  final String formId;
  final String formName;

  const EditorScreen({
    super.key,
    required this.formId,
    required this.formName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EditorCubit(getIt())..loadForm(formId),
      child: _EditorView(formId: formId, initialName: formName),
    );
  }
}

class _EditorView extends StatelessWidget {
  final String formId;
  final String initialName;

  const _EditorView({required this.formId, required this.initialName});

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorCubit, EditorState>(
      listener: _onStateChange,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: _AppBarTitle(initialName: initialName),
          actions: [
            BlocSelector<EditorCubit, EditorState,
                ({bool isDirty, bool isSaving})>(
              selector: (state) => state is EditorLoaded
                  ? (isDirty: state.isDirty, isSaving: state.isSaving)
                  : (isDirty: false, isSaving: false),
              builder: (context, data) {
                if (data.isSaving) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return TextButton(
                  onPressed: data.isDirty
                      ? () => context.read<EditorCubit>().save()
                      : null,
                  child: const Text('Save'),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {}, // settings / preview / share — step 12
            ),
          ],
        ),
        body: BlocBuilder<EditorCubit, EditorState>(
          // Only rebuild when the state class changes (Loading↔Loaded↔Error).
          // All content updates inside EditorLoaded are handled by the
          // per-item BlocSelectors inside _EditorBody.
          buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
          builder: (context, state) => switch (state) {
            EditorLoading() =>
              const Center(child: CircularProgressIndicator()),
            EditorError(:final kind, :final message)
                when kind == EditorErrorKind.network =>
              _FullScreenError(
                message: message,
                onRetry: () =>
                    context.read<EditorCubit>().loadForm(formId),
              ),
            EditorError() => const SizedBox.shrink(),
            EditorLoaded() => const _EditorBody(),
          },
        ),
        bottomNavigationBar: BlocSelector<EditorCubit, EditorState, bool>(
          selector: (state) =>
              state is EditorLoaded && !state.isSaving,
          builder: (context, enabled) => _BottomBar(enabled: enabled),
        ),
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

// ── App bar title — rebuilds only when the form title changes ─────────────────

class _AppBarTitle extends StatelessWidget {
  final String initialName;

  const _AppBarTitle({required this.initialName});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState, String>(
      selector: (state) =>
          state is EditorLoaded ? state.form.info.title : initialName,
      builder: (context, title) => Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Value objects for BlocSelectors ──────────────────────────────────────────

/// Structural data for the editor body — item IDs + form header text.
/// Implements == so BlocSelector only rebuilds on actual changes.
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

/// Per-item data — the item itself and the current sections list.
/// Implements == so BlocSelector only rebuilds when this item or
/// the section list changes.
class _ItemData {
  final Item? item;
  final List<Item> sections;

  const _ItemData({required this.item, required this.sections});

  @override
  bool operator ==(Object other) =>
      other is _ItemData &&
      other.item == item &&
      listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(item, Object.hashAll(sections));
}

// ── Editor body ───────────────────────────────────────────────────────────────

/// Renders the scrollable form editor. Uses its own [BlocSelector] for
/// structural data (item IDs + header), so it only rebuilds when items are
/// added, removed, or reordered — not on every keystroke.
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

        if (data.itemIds.isEmpty) {
          return CustomScrollView(
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
                    child: _ItemRow(itemId: data.itemIds[i]),
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

/// Wraps a single form item with its own [BlocSelector].
/// Only rebuilds when THIS item's content or the sections list changes.
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
        return _ItemData(item: item, sections: sections);
      },
      builder: (context, data) {
        final item = data.item;
        if (item == null) return const SizedBox.shrink();
        return switch (item.content) {
          QuestionItemContent() || QuestionGroupItemContent() =>
            QuestionCard(item: item, sections: data.sections),
          PageBreakItemContent() => SectionCard(item: item),
          TextItemContent() => TextBlockCard(item: item),
          ImageItemContent() => _ImageCard(item: item),
          VideoItemContent() => _VideoCard(item: item),
        };
      },
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool enabled;

  const _BottomBar({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: enabled
                    ? () => context.read<EditorCubit>().addQuestion()
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: enabled
                  ? () => context.read<EditorCubit>().addSection()
                  : null,
              icon: const Icon(Icons.view_agenda_outlined),
              tooltip: 'Add section',
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              onPressed: null, // step 10
              icon: const Icon(Icons.perm_media_outlined),
              tooltip: 'Add media',
            ),
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
