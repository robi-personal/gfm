import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/item.dart';
import '../cubit/editor_cubit.dart';

const _purple = Color(0xFF772FC0);

/// Section break card — same card design as question cards.
class SectionCard extends StatelessWidget {
  final Item item;

  const SectionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left purple accent border
            Container(width: 4, color: _purple),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + section chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title?.isNotEmpty == true
                                ? item.title!
                                : 'Section',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _purple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Section',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Description
                    if (item.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Divider(height: 12),
                    // Action row
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 20,
                          color: cs.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete section',
                          onPressed: () =>
                              context.read<EditorCubit>().deleteItem(item.itemId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 20,
                          color: cs.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit section',
                          onPressed: () =>
                              _SectionEditSheet.show(context, item),
                        ),
                      ],
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

// ── Section edit sheet ────────────────────────────────────────────────────────

class _SectionEditSheet extends StatefulWidget {
  final Item item;

  const _SectionEditSheet({required this.item});

  static Future<void> show(BuildContext context, Item item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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

  static InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF3F0FA),
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
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeArea = MediaQuery.of(context).padding.bottom;
    final bottom = viewInsets + safeArea;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit section',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _commit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                  decoration: _inputDec('Section title'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  style: const TextStyle(
                      fontSize: 15, color: Colors.black87),
                  decoration: _inputDec('Description (optional)'),
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

// ── Text block card ───────────────────────────────────────────────────────────

class TextBlockCard extends StatelessWidget {
  final Item item;

  const TextBlockCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: _purple),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title?.isNotEmpty == true
                                ? item.title!
                                : 'Text block',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Text',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Divider(height: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 20,
                          color: cs.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete text block',
                          onPressed: () =>
                              context.read<EditorCubit>().deleteItem(item.itemId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 20,
                          color: cs.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit text block',
                          onPressed: () =>
                              TextBlockEditSheet.show(context, item),
                        ),
                      ],
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

// ── Text block edit sheet ─────────────────────────────────────────────────────

class TextBlockEditSheet extends StatefulWidget {
  final Item item;

  const TextBlockEditSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, Item item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<EditorCubit>(),
        child: TextBlockEditSheet(item: item),
      ),
    );
  }

  @override
  State<TextBlockEditSheet> createState() => _TextBlockEditSheetState();
}

class _TextBlockEditSheetState extends State<TextBlockEditSheet> {
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
      title: _titleCtrl.text.isEmpty ? 'Text block' : _titleCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
    );
    context.read<EditorCubit>().updateItemFull(updatedItem);
    Navigator.of(context).pop();
  }

  static InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF3F0FA),
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
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeArea = MediaQuery.of(context).padding.bottom;
    final bottom = viewInsets + safeArea;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit text block',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _commit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                  decoration: _inputDec('Title'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: _inputDec('Description (optional)'),
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
