import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/item.dart';
import '../../../core/models/item_content.dart';
import '../../../core/models/question_kind.dart';
import 'type_chip.dart';

/// Tappable, expandable card for a question item.
/// Collapsed: title + type chip.
/// Expanded: full preview + required toggle (read-only in step 5, editable in step 6+).
class QuestionCard extends StatefulWidget {
  final Item item;

  const QuestionCard({super.key, required this.item});

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  bool _expanded = false;

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
    final required = question.required as bool;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: _expanded ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: _expanded
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title?.isNotEmpty == true
                          ? widget.item.title!
                          : 'Question',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (required)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Text('*',
                          style: TextStyle(
                              color: theme.colorScheme.error, fontSize: 16)),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // ── Type chip (always visible) ────────────────────────────────
              const SizedBox(height: 8),
              TypeChip(kind: kind),

              // ── Expanded content ──────────────────────────────────────────
              if (_expanded) ...[
                if (widget.item.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.item.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                _buildPreview(context, kind),
                const SizedBox(height: 16),
                _RequiredRow(required: required),
              ],
            ],
          ),
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
      elevation: _expanded ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: _expanded
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title?.isNotEmpty == true
                          ? widget.item.title!
                          : 'Question group',
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const TypeChip(
                  kind: ChoiceQuestion(
                      type: ChoiceType.radio, options: [])),
              if (_expanded && columns.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Column headers
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, QuestionKind kind) {
    return switch (kind) {
      TextQuestion(:final paragraph) => _TextPreview(paragraph: paragraph),
      ChoiceQuestion(:final type, :final options) =>
        _ChoicePreview(type: type, options: options, showAll: true),
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
}

// ── Required row ──────────────────────────────────────────────────────────────

class _RequiredRow extends StatelessWidget {
  final bool required;

  const _RequiredRow({required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Required',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Switch(
          value: required,
          onChanged: null, // read-only in step 5; wired in step 8
        ),
      ],
    );
  }
}

// ── Question previews ─────────────────────────────────────────────────────────

class _TextPreview extends StatelessWidget {
  final bool paragraph;

  const _TextPreview({required this.paragraph});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor)),
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

class _ChoicePreview extends StatelessWidget {
  final ChoiceType type;
  final List<dynamic> options;
  final bool showAll;

  const _ChoicePreview(
      {required this.type, required this.options, this.showAll = false});

  @override
  Widget build(BuildContext context) {
    final visible = showAll ? options : options.take(4).toList();
    final overflow = showAll ? 0 : options.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map((o) =>
            _OptionRow(type: type, label: o.value as String)),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('+ $overflow more',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final ChoiceType type;
  final String label;

  const _OptionRow({required this.type, required this.label});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      ChoiceType.radio => Icons.radio_button_unchecked,
      ChoiceType.checkbox => Icons.check_box_outline_blank,
      ChoiceType.dropDown => Icons.arrow_drop_down_circle_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
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
          child: Icon(icon, size: 22,
              color: Theme.of(context).colorScheme.primary),
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
        Icon(icon, size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic)),
      ],
    );
  }
}
