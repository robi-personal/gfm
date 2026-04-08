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
    return BlocConsumer<EditorCubit, EditorState>(
      listener: (context, state) {
        // Conflict modal — shown exactly once per conflict event.
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
              break; // shown as full-screen error in body
          }
        }
      },
      builder: (context, state) {
        final title = state is EditorLoaded
            ? state.form.info.title
            : initialName;
        final saveStatus =
            state is EditorLoaded ? state.saveStatus : null;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (saveStatus != null)
                  Text(
                    _saveLabel(saveStatus),
                    style: TextStyle(
                      fontSize: 11,
                      color: _saveLabelColor(context, saveStatus),
                    ),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {}, // settings / preview / share — step 12
              ),
            ],
          ),
          body: switch (state) {
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
            EditorLoaded(:final form) => _ItemList(form: form),
          },
          bottomNavigationBar: state is EditorLoaded
              ? _BottomBar(form: state.form)
              : const _BottomBar(form: null),
        );
      },
    );
  }

  String _saveLabel(String status) => switch (status) {
        'saving' => 'Saving…',
        'retrying' => 'Retrying…',
        'offline' => 'Offline',
        'unpublished' => 'Unpublished',
        _ => 'Saved',
      };

  Color _saveLabelColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      'saving' || 'retrying' => cs.onSurfaceVariant,
      'offline' => cs.error,
      'unpublished' => cs.tertiary,
      _ => cs.primary,
    };
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  final dynamic form;

  const _ItemList({required this.form});

  @override
  Widget build(BuildContext context) {
    final items = form.items as List<Item>;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No questions yet.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      onReorder: (oldIndex, newIndex) {
        // ReorderableListView passes newIndex after removal; adjust by -1 when
        // moving down (standard Flutter behavior).
        final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
        context.read<EditorCubit>().moveItem(oldIndex, to);
      },
      buildDefaultDragHandles: false,
      itemCount: items.length + 1, // +1 for header
      itemBuilder: (context, i) {
        if (i == 0) {
          return FormHeaderCard(
            key: const ValueKey('__header__'),
            initialTitle: form.info.title as String,
            initialDescription: form.info.description as String?,
          );
        }
        final item = items[i - 1];
        return ReorderableDragStartListener(
          key: ValueKey(item.itemId),
          index: i,
          child: _buildItem(item),
        );
      },
    );
  }

  Widget _buildItem(Item item) => switch (item.content) {
        QuestionItemContent() || QuestionGroupItemContent() =>
          QuestionCard(key: ValueKey(item.itemId), item: item),
        PageBreakItemContent() =>
          SectionCard(key: ValueKey(item.itemId), item: item),
        TextItemContent() =>
          TextBlockCard(key: ValueKey(item.itemId), item: item),
        ImageItemContent() =>
          _ImageCard(key: ValueKey(item.itemId), item: item),
        VideoItemContent() =>
          _VideoCard(key: ValueKey(item.itemId), item: item),
      };
}

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final dynamic form;

  const _BottomBar({required this.form});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = form != null;
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
                    ? () {
                        final items = form.items as List<Item>;
                        context.read<EditorCubit>().addQuestion(
                              afterIndex: items.isEmpty ? null : items.length - 1,
                            );
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              // Section support — step 10
              onPressed: null,
              icon: const Icon(Icons.view_agenda_outlined),
              tooltip: 'Add section',
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              // Media — step 10
              onPressed: null,
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

  const _ImageCard({super.key, required this.item});

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

  const _VideoCard({super.key, required this.item});

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

// ── Shared error widget ───────────────────────────────────────────────────────

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
