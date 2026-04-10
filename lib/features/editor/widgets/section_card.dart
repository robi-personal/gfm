import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/item.dart';
import '../editor_cubit.dart';

/// Static section divider for a [PageBreakItemContent].
class SectionCard extends StatelessWidget {
  final Item item;

  const SectionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider line
          Row(
            children: [
              Expanded(child: Divider(color: cs.primary)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.horizontal_rule, size: 16, color: cs.primary),
              ),
              Expanded(child: Divider(color: cs.primary)),
            ],
          ),
          const SizedBox(height: 4),
          // Title
          Text(
            item.title?.isNotEmpty == true ? item.title! : 'Section',
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Description
          if (item.description?.isNotEmpty == true) ...[
            const SizedBox(height: 2),
            Text(
              item.description!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          // Action row
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                iconSize: 18,
                color: cs.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete section',
                onPressed: () =>
                    context.read<EditorCubit>().deleteItem(item.itemId),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _SectionEditSheet.show(context, item),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section edit sheet ────────────────────────────────────────────────────────

class _SectionEditSheet extends StatefulWidget {
  final Item item;

  const _SectionEditSheet({required this.item});

  static Future<void> show(BuildContext context, Item item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<EditorCubit>(),
        child: _SectionEditSheet(item: item),
      ),
    );
  }

  @override
  State<_SectionEditSheet> createState() => _SectionEditSheetState();
}

class _SectionEditSheetState extends State<_SectionEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title ?? '');
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final updatedItem = widget.item.copyWith(
      title: _titleCtrl.text.isEmpty ? 'Section' : _titleCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
    );
    context.read<EditorCubit>().updateItemFull(updatedItem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Edit section',
                      style: theme.textTheme.titleMedium),
                ),
                FilledButton.tonal(
                  onPressed: _commit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600, color: cs.primary),
                  decoration: const InputDecoration(
                    labelText: 'Section title',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inert text block ──────────────────────────────────────────────────────────

class TextBlockCard extends StatelessWidget {
  final Item item;

  const TextBlockCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.title?.isNotEmpty == true)
              Text(item.title!,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            if (item.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(item.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
