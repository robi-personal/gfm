import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/models/item.dart';
import '../../core/models/item_content.dart';
import '../../core/widgets/error_modal.dart';
import 'editor_cubit.dart';
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
              break; // shown inline
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
            EditorLoaded(:final form) => _ItemList(items: form.items),
          },
          bottomNavigationBar: _BottomBar(),
        );
      },
    );
  }

  String _saveLabel(String status) => switch (status) {
        'saving' => 'Saving…',
        'offline' => 'Offline',
        'unpublished' => 'Unpublished',
        _ => 'Saved',
      };

  Color _saveLabelColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      'saving' => cs.onSurfaceVariant,
      'offline' => cs.error,
      'unpublished' => cs.tertiary,
      _ => cs.primary,
    };
  }
}

// ── Item list ─────────────────────────────────────────────────────────────────

class _ItemList extends StatelessWidget {
  final List<Item> items;

  const _ItemList({required this.items});

  @override
  Widget build(BuildContext context) {
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

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildItem(items[i]),
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

// ── Bottom bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar();

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
                // TODO(step-7): wire add question
                onPressed: null,
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              // TODO(step-10): add section
              onPressed: null,
              icon: const Icon(Icons.view_agenda_outlined),
              tooltip: 'Add section',
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              // TODO(step-10): add media
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
