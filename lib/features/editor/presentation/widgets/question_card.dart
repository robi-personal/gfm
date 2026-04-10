import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question.dart';
import '../../../../core/models/question_kind.dart';
import '../cubit/editor_cubit.dart';
import 'question_edit_sheet.dart';
import 'type_chip.dart';

const _purple = Color(0xFF772FC0);

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

  Widget _buildSingle(BuildContext context, Question question) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final kind = question.kind;
    final isRequired = question.required;

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
                    // ── Title + type chip ─────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title?.isNotEmpty == true
                                ? item.title!
                                : 'Question name',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: item.title?.isNotEmpty == true
                                  ? null
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TypeChip(kind: kind),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Content preview ───────────────────────────────────
                    _ContentPreview(kind: kind),
                    // ── "Add Option" link (choice questions only) ─────────
                    if (kind is ChoiceQuestion) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => QuestionEditSheet.show(
                          context, item, sections,
                          isQuiz: isQuiz,
                        ),
                        child: Text(
                          'Add Option  Or  Add "Other"',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Divider(height: 12),
                    // ── Bottom action row ─────────────────────────────────
                    Row(
                      children: [
                        // Delete
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          iconSize: 20,
                          color: cs.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete',
                          onPressed: () =>
                              context.read<EditorCubit>().deleteItem(item.itemId),
                        ),
                        // Edit
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          iconSize: 20,
                          color: cs.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit',
                          onPressed: () => QuestionEditSheet.show(
                            context, item, sections,
                            isQuiz: isQuiz,
                          ),
                        ),
                        const Spacer(),
                        // Required label + compact switch
                        Text(
                          'Required',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: isRequired,
                            activeColor: _purple,
                            onChanged: (value) {
                              final content =
                                  item.content as QuestionItemContent;
                              final updatedItem = item.copyWith(
                                content: content.copyWith(
                                  question: question.copyWith(
                                    required: value,
                                  ),
                                ),
                              );
                              context
                                  .read<EditorCubit>()
                                  .updateItemFull(updatedItem);
                            },
                          ),
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

  Widget _buildGroup(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = item.content as QuestionGroupItemContent;
    final colCount = content.grid?.columns.options.length ?? 0;

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
                                : 'Question group',
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const TypeChip(
                            kind: ChoiceQuestion(
                                type: ChoiceType.radio, options: [])),
                      ],
                    ),
                    if (colCount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${content.questions.length} rows · $colCount columns',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const Divider(height: 20),
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
      ChoiceQuestion(:final options, :final type) =>
        _OptionsPreview(options: options, type: type),
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
  final ChoiceType type;
  const _OptionsPreview({required this.options, required this.type});

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

    final leadingIcon = switch (type) {
      ChoiceType.radio => Icons.radio_button_unchecked,
      ChoiceType.checkbox => Icons.check_box_outline_blank,
      ChoiceType.dropDown => Icons.arrow_drop_down_circle_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...shown.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(leadingIcon, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
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
            padding: const EdgeInsets.only(left: 24, top: 2),
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
