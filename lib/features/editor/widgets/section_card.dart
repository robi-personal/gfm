import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/item.dart';
import '../editor_cubit.dart';

/// Editable section divider for a [PageBreakItemContent].
class SectionCard extends StatefulWidget {
  final Item item;

  const SectionCard({super.key, required this.item});

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late FocusNode _titleFocus;
  late FocusNode _descFocus;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title ?? '');
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
    _titleFocus = FocusNode();
    _descFocus = FocusNode();
  }

  @override
  void didUpdateWidget(SectionCard old) {
    super.didUpdateWidget(old);
    final newTitle = widget.item.title ?? '';
    if (_titleCtrl.text != newTitle && !_titleFocus.hasFocus) {
      _titleCtrl.text = newTitle;
    }
    final newDesc = widget.item.description ?? '';
    if (_descCtrl.text != newDesc && !_descFocus.hasFocus) {
      _descCtrl.text = newDesc;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Divider ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: cs.primary)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child:
                    Icon(Icons.horizontal_rule, size: 16, color: cs.primary),
              ),
              Expanded(child: Divider(color: cs.primary)),
            ],
          ),
          const SizedBox(height: 4),
          // ── Title field ───────────────────────────────────────────────────
          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Section title',
              hintStyle: theme.textTheme.titleSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              isDense: true,
            ),
            onChanged: (v) =>
                context.read<EditorCubit>().updateItemTitle(widget.item.itemId, v),
          ),
          // ── Description field ─────────────────────────────────────────────
          TextField(
            controller: _descCtrl,
            focusNode: _descFocus,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            decoration: InputDecoration(
              hintText: 'Section description (optional)',
              hintStyle: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              isDense: true,
            ),
            minLines: 1,
            maxLines: 3,
            onChanged: (v) => context
                .read<EditorCubit>()
                .updateItemDescription(widget.item.itemId, v),
          ),
          // ── Delete button ─────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              iconSize: 18,
              color: cs.onSurfaceVariant,
              tooltip: 'Delete section',
              onPressed: () =>
                  context.read<EditorCubit>().deleteItem(widget.item.itemId),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inert text block ([TextItemContent]).
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
