import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/choice_option.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/item.dart';
import '../../../core/models/item_content.dart';
import '../../../core/models/question_kind.dart';
import '../editor_cubit.dart';
import 'question_edit_sheet.dart';
import 'type_chip.dart';

/// Static (read-only) card for a question item.
/// All editing happens via [QuestionEditSheet] opened from the Edit button.
class QuestionCard extends StatelessWidget {
  final Item item;

  /// Page-break items — passed through to the edit sheet for branching UI.
  final List<Item> sections;

  /// Whether the form is in quiz mode — forwarded to the edit sheet.
  final bool isQuiz;

  const QuestionCard({
    super.key,
    required this.item,
    this.sections = const [],
    this.isQuiz = false,
  });

  @override
  Widget build(BuildContext context) {
    return switch (item.content) {
      QuestionItemContent(:final question) => _buildSingle(context, question),
      QuestionGroupItemContent() => _buildGroup(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSingle(BuildContext context, dynamic question) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kind = question.kind as QuestionKind;
    final isRequired = question.required as bool;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title + required badge ────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title?.isNotEmpty == true ? item.title! : 'Question',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                if (isRequired)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Type chip ─────────────────────────────────────────────────
            TypeChip(kind: kind),
            const SizedBox(height: 10),
            // ── Content preview ───────────────────────────────────────────
            _ContentPreview(kind: kind),
            // ── Action row ────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete',
                  onPressed: () =>
                      context.read<EditorCubit>().deleteItem(item.itemId),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      QuestionEditSheet.show(
                        context, item, sections,
                        isQuiz: isQuiz,
                      ),
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
      ),
    );
  }

  Widget _buildGroup(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = item.content as QuestionGroupItemContent;
    final colCount = content.grid?.columns.options.length ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title?.isNotEmpty == true ? item.title! : 'Question group',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const TypeChip(
                kind: ChoiceQuestion(type: ChoiceType.radio, options: [])),
            if (colCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${content.questions.length} rows · $colCount columns',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete',
                  onPressed: () =>
                      context.read<EditorCubit>().deleteItem(item.itemId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content preview widget ────────────────────────────────────────────────────

class _ContentPreview extends StatelessWidget {
  final QuestionKind kind;
  const _ContentPreview({required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return switch (kind) {
      ChoiceQuestion(:final options) => _OptionsPreview(options: options),
      TextQuestion(:final paragraph) => _PreviewLine(
          paragraph ? 'Long answer text' : 'Short answer text'),
      ScaleQuestion(:final low, :final high) => Text(
          'Scale $low – $high',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      DateQuestion() =>
        _IconLine(Icons.calendar_today, 'Date'),
      TimeQuestion(:final duration) =>
        _IconLine(Icons.access_time, duration ? 'Duration' : 'Time'),
      RatingQuestion(:final ratingScaleLevel, :final iconType) =>
        _RatingLine(count: ratingScaleLevel, iconType: iconType),
      FileUploadQuestion() =>
        _IconLine(Icons.upload_file, 'File upload'),
      RowQuestion() => const SizedBox.shrink(),
    };
  }
}

class _OptionsPreview extends StatelessWidget {
  final List<ChoiceOption> options;
  const _OptionsPreview({required this.options});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (options.isEmpty) {
      return Text(
        'No options — tap Edit to add some.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    const maxShown = 3;
    final shown = options.take(maxShown).toList();
    final overflow = options.length - maxShown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...shown.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 5, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      o.value,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 2),
            child: Text(
              '+ $overflow more',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final String text;
  const _PreviewLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconLine(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _RatingLine extends StatelessWidget {
  final int count;
  final RatingIconType iconType;
  const _RatingLine({required this.count, required this.iconType});

  @override
  Widget build(BuildContext context) {
    final icon = switch (iconType) {
      RatingIconType.star => Icons.star_border,
      RatingIconType.heart => Icons.favorite_border,
      RatingIconType.thumbUp => Icons.thumb_up_outlined,
    };
    return Row(
      children: List.generate(
        count.clamp(1, 10),
        (_) => Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(icon, size: 18,
              color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
