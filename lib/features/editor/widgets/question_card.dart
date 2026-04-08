import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/item.dart';
import '../../../core/models/item_content.dart';
import '../../../core/models/question_kind.dart';
import 'type_chip.dart';

/// Read-only card for a [QuestionItemContent] or [QuestionGroupItemContent].
/// Tap-to-expand and editing are added in step 6+.
class QuestionCard extends StatelessWidget {
  final Item item;

  const QuestionCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return switch (item.content) {
      QuestionItemContent(:final question) => _SingleQuestionCard(
          item: item,
          question: question,
        ),
      QuestionGroupItemContent(:final questions, :final grid) =>
        _GroupQuestionCard(
          item: item,
          questions: questions,
          grid: grid,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _SingleQuestionCard extends StatelessWidget {
  final Item item;
  final dynamic question; // Question

  const _SingleQuestionCard({required this.item, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = question.kind as QuestionKind;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title?.isNotEmpty == true
                        ? item.title!
                        : 'Question',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (question.required as bool)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Text('*',
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 16)),
                  ),
              ],
            ),
            if (item.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                item.description!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            TypeChip(kind: kind),
            const SizedBox(height: 12),
            _buildPreview(context, kind),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, QuestionKind kind) {
    return switch (kind) {
      TextQuestion(:final paragraph) => _TextPreview(paragraph: paragraph),
      ChoiceQuestion(:final type, :final options) =>
        _ChoicePreview(type: type, options: options),
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
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
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

  const _ChoicePreview({required this.type, required this.options});

  @override
  Widget build(BuildContext context) {
    final visibleOptions = options.take(4).toList();
    final overflow = options.length - visibleOptions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleOptions.map((o) => _OptionRow(type: type, label: o.value as String)),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ $overflow more',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
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
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
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

  const _ScalePreview({
    required this.low,
    required this.high,
    this.lowLabel,
    this.highLabel,
  });

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
              (i) => Text(
                '${low + i}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  fontStyle: FontStyle.italic,
                )),
      ],
    );
  }
}

// ── Question group card ───────────────────────────────────────────────────────

class _GroupQuestionCard extends StatelessWidget {
  final Item item;
  final List<dynamic> questions;
  final dynamic grid;

  const _GroupQuestionCard({
    required this.item,
    required this.questions,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns =
        grid != null ? (grid.columns.options as List).map((o) => o.value as String).toList() : <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title?.isNotEmpty == true ? item.title! : 'Question group',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const TypeChip(kind: ChoiceQuestion(
              type: ChoiceType.radio,
              options: [],
            )),
            const SizedBox(height: 12),
            // Column headers
            if (columns.isNotEmpty)
              Row(
                children: [
                  const SizedBox(width: 120),
                  ...columns.map((c) => Expanded(
                        child: Text(c,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600)),
                      )),
                ],
              ),
            // Row questions
            ...questions.map((q) {
              final title = q.kind is RowQuestion
                  ? (q.kind as RowQuestion).title
                  : '';
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
        ),
      ),
    );
  }
}
