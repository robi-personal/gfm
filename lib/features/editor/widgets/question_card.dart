import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/choice_option.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/item.dart';
import '../../../core/models/item_content.dart';
import '../../../core/models/question_kind.dart';
import '../editor_cubit.dart';
import 'type_chip.dart';
import 'type_picker_sheet.dart';

/// Always-expanded card for a question item.
class QuestionCard extends StatefulWidget {
  final Item item;

  const QuestionCard({super.key, required this.item});

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  late TextEditingController _titleCtrl;
  FocusNode? _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title ?? '');
  }

  @override
  void didUpdateWidget(QuestionCard old) {
    super.didUpdateWidget(old);
    final newTitle = widget.item.title ?? '';
    if (_titleCtrl.text != newTitle && !(_titleFocusNode?.hasFocus ?? false)) {
      _titleCtrl.text = newTitle;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    // _titleFocusNode is owned and disposed by _TitleFieldState — do NOT dispose here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.item.content) {
      QuestionItemContent(:final question) => _buildSingle(context, question),
      QuestionGroupItemContent(:final questions, :final grid) =>
        _buildGroup(context, questions, grid),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSingle(BuildContext context, dynamic question) {
    final theme = Theme.of(context);
    final kind = question.kind as QuestionKind;
    final isRequired = question.required as bool;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title field ───────────────────────────────────────────────
            _TitleField(
              controller: _titleCtrl,
              itemId: widget.item.itemId,
              onFocusNode: (fn) => _titleFocusNode = fn,
            ),
            // ── Type chip ─────────────────────────────────────────────────
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickType(context, kind),
              child: TypeChip(kind: kind, showCaret: true),
            ),
            // ── Description ───────────────────────────────────────────────
            if (widget.item.description?.isNotEmpty == true) ...{
              const SizedBox(height: 8),
              Text(
                widget.item.description!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            },
            // ── Editable content ──────────────────────────────────────────
            const SizedBox(height: 12),
            _buildEditableContent(context, kind),
            const SizedBox(height: 16),
            _ActionRow(itemId: widget.item.itemId, isRequired: isRequired),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(
      BuildContext context, List<dynamic> questions, dynamic grid) {
    final theme = Theme.of(context);
    final columns = grid != null
        ? (grid.columns.options as List).map((o) => o.value as String).toList()
        : <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title?.isNotEmpty == true
                  ? widget.item.title!
                  : 'Question group',
              style:
                  theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const TypeChip(
                kind: ChoiceQuestion(type: ChoiceType.radio, options: [])),
            if (columns.isNotEmpty) ...{
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 120),
                  ...columns.map((c) => Expanded(
                        child: Text(c,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      )),
                ],
              ),
              const SizedBox(height: 4),
              ...questions.map((q) {
                final title =
                    q.kind is RowQuestion ? (q.kind as RowQuestion).title : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(title,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis),
                      ),
                      ...List.generate(
                        columns.length,
                        (_) => Expanded(
                          child: Icon(Icons.radio_button_unchecked,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildEditableContent(BuildContext context, QuestionKind kind) {
    return switch (kind) {
      ChoiceQuestion(:final type, :final options) => _EditableOptions(
          itemId: widget.item.itemId,
          type: type,
          options: options.cast<ChoiceOption>(),
        ),
      TextQuestion(:final paragraph) => _TextPreview(paragraph: paragraph),
      ScaleQuestion(:final low, :final high, :final lowLabel, :final highLabel) =>
        _ScalePreview(
            low: low, high: high, lowLabel: lowLabel, highLabel: highLabel),
      DateQuestion() => _IconPreview(Icons.calendar_today, 'Date'),
      TimeQuestion(:final duration) =>
        _IconPreview(Icons.access_time, duration ? 'Duration' : 'Time'),
      RatingQuestion(:final ratingScaleLevel, :final iconType) =>
        _RatingPreview(
            ratingScaleLevel: ratingScaleLevel, iconType: iconType),
      FileUploadQuestion() => _IconPreview(Icons.upload_file, 'File upload'),
      RowQuestion() => const SizedBox.shrink(),
    };
  }

  Future<void> _pickType(BuildContext context, QuestionKind current) async {
    final picked = await TypePickerSheet.show(context, current);
    if (picked == null || !context.mounted) return;

    // Preserve options when switching between choice types.
    final kind = _mergeOptions(current, picked);
    context.read<EditorCubit>().updateQuestionType(widget.item.itemId, kind);
  }

  /// Ensure choice questions always have at least one option, and carry
  /// existing options over when switching between choice types.
  QuestionKind _mergeOptions(QuestionKind old, QuestionKind next) {
    if (next is ChoiceQuestion) {
      final options = old is ChoiceQuestion && old.options.isNotEmpty
          ? old.options
          : [ChoiceOption(value: 'Option 1')];
      return next.copyWith(options: options);
    }
    return next;
  }
}

// ── Title field ───────────────────────────────────────────────────────────────

class _TitleField extends StatefulWidget {
  final TextEditingController controller;
  final String itemId;
  final void Function(FocusNode) onFocusNode;

  const _TitleField({
    required this.controller,
    required this.itemId,
    required this.onFocusNode,
  });

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    widget.onFocusNode(_focus);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      style:
          theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Question',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      onChanged: (v) =>
          context.read<EditorCubit>().updateItemTitle(widget.itemId, v),
      minLines: 1,
      maxLines: 4,
    );
  }
}

// ── Editable options ──────────────────────────────────────────────────────────

class _EditableOptions extends StatelessWidget {
  final String itemId;
  final ChoiceType type;
  final List<ChoiceOption> options;

  const _EditableOptions({
    required this.itemId,
    required this.type,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(options.length, (i) {
          final opt = options[i];
          return _OptionEditRow(
            itemId: itemId,
            optionIndex: i,
            value: opt.value,
            type: type,
            canRemove: options.length > 1,
          );
        }),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () =>
              context.read<EditorCubit>().addOption(itemId),
          icon: Icon(Icons.add, size: 18,
              color: theme.colorScheme.primary),
          label: Text('Add option',
              style: TextStyle(color: theme.colorScheme.primary)),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0)),
        ),
      ],
    );
  }
}

class _OptionEditRow extends StatefulWidget {
  final String itemId;
  final int optionIndex;
  final String value;
  final ChoiceType type;
  final bool canRemove;

  const _OptionEditRow({
    required this.itemId,
    required this.optionIndex,
    required this.value,
    required this.type,
    required this.canRemove,
  });

  @override
  State<_OptionEditRow> createState() => _OptionEditRowState();
}

class _OptionEditRowState extends State<_OptionEditRow> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(_OptionEditRow old) {
    super.didUpdateWidget(old);
    // Only sync from external state when the user isn't actively typing.
    if (widget.value != _ctrl.text && !_focus.hasFocus) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (widget.type) {
      ChoiceType.radio => Icons.radio_button_unchecked,
      ChoiceType.checkbox => Icons.check_box_outline_blank,
      ChoiceType.dropDown => Icons.arrow_drop_down_circle_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: theme.colorScheme.primary),
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onChanged: (v) => context
                  .read<EditorCubit>()
                  .updateOptionText(widget.itemId, widget.optionIndex, v),
            ),
          ),
          if (widget.canRemove)
            GestureDetector(
              onTap: () => context
                  .read<EditorCubit>()
                  .removeOption(widget.itemId, widget.optionIndex),
              child: Icon(Icons.close,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ── Action row (required toggle + delete) ────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final String itemId;
  final bool isRequired;

  const _ActionRow({required this.itemId, required this.isRequired});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          iconSize: 20,
          color: theme.colorScheme.onSurfaceVariant,
          tooltip: 'Delete',
          onPressed: () => context.read<EditorCubit>().deleteItem(itemId),
        ),
        const Spacer(),
        Text('Required',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Switch(
          value: isRequired,
          onChanged: (v) =>
              context.read<EditorCubit>().updateRequired(itemId, v),
        ),
      ],
    );
  }
}

// ── Read-only previews (collapsed and non-choice expanded) ───────────────────

class _TextPreview extends StatelessWidget {
  final bool paragraph;

  const _TextPreview({required this.paragraph});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text(
        paragraph ? 'Long answer text' : 'Short answer text',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

class _ScalePreview extends StatelessWidget {
  final int low;
  final int high;
  final String? lowLabel;
  final String? highLabel;

  const _ScalePreview(
      {required this.low,
      required this.high,
      this.lowLabel,
      this.highLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (lowLabel != null)
          Text(lowLabel!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              high - low + 1,
              (i) => Text('${low + i}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (highLabel != null)
          Text(highLabel!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _RatingPreview extends StatelessWidget {
  final int ratingScaleLevel;
  final RatingIconType iconType;

  const _RatingPreview(
      {required this.ratingScaleLevel, required this.iconType});

  @override
  Widget build(BuildContext context) {
    final icon = switch (iconType) {
      RatingIconType.star => Icons.star_border,
      RatingIconType.heart => Icons.favorite_border,
      RatingIconType.thumbUp => Icons.thumb_up_outlined,
    };
    return Row(
      children: List.generate(
        ratingScaleLevel.clamp(1, 10),
        (_) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _IconPreview extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconPreview(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic)),
      ],
    );
  }
}
