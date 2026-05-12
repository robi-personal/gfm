import 'package:flutter/cupertino.dart';
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
const _primaryText = Color(0xFF1C1C1E);
const _secondaryText = Color(0xFF8E8E93);
const _separator = Color(0xFFE8E8E8);

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
    final kind = question.kind;
    final isRequired = question.required;

    return _CardShell(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left purple accent bar
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: item.title?.isNotEmpty == true
                                  ? _primaryText
                                  : _secondaryText,
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
                        child: const Text(
                          'Add Option  ·  Add "Other"',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _purple,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Divider(height: 16, color: _separator),
                    // ── Bottom action row ─────────────────────────────────
                    Row(
                      children: [
                        // Delete
                        _ActionButton(
                          icon: CupertinoIcons.trash,
                          tooltip: 'Delete',
                          onPressed: () =>
                              context.read<EditorCubit>().deleteItem(item.itemId),
                        ),
                        // Edit
                        _ActionButton(
                          icon: CupertinoIcons.pencil,
                          tooltip: 'Edit',
                          onPressed: () => QuestionEditSheet.show(
                            context, item, sections,
                            isQuiz: isQuiz,
                          ),
                        ),
                        const Spacer(),
                        // Required label + compact switch
                        const Text(
                          'Required',
                          style: TextStyle(fontSize: 12, color: _secondaryText),
                        ),
                        const SizedBox(width: 6),
                        Transform.scale(
                          scale: 0.75,
                          child: CupertinoSwitch(
                            value: isRequired,
                            activeTrackColor: _purple,
                            onChanged: (value) {
                              final content =
                                  item.content as QuestionItemContent;
                              context.read<EditorCubit>().updateItemFull(
                                    item.copyWith(
                                      content: content.copyWith(
                                        question: question.copyWith(
                                          required: value,
                                        ),
                                      ),
                                    ),
                                  );
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
    final content = item.content as QuestionGroupItemContent;
    final colCount = content.grid?.columns.options.length ?? 0;

    return _CardShell(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: _purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _primaryText,
                            ),
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
                        style: const TextStyle(
                            fontSize: 12, color: _secondaryText),
                      ),
                    ],
                    const Divider(height: 20, color: _separator),
                    Row(
                      children: [
                        _ActionButton(
                          icon: CupertinoIcons.trash,
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

// ── Shared card shell ─────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ── Action icon button ────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minSize: 0,
        onPressed: onPressed,
        child: Icon(icon, size: 18, color: _secondaryText),
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
    return switch (kind) {
      ChoiceQuestion(:final options, :final type) =>
        _OptionsPreview(options: options, type: type),
      TextQuestion(:final paragraph) => _PreviewLine(
          paragraph ? 'Long answer text' : 'Short answer text'),
      ScaleQuestion(:final low, :final high) => Text(
          'Scale $low – $high',
          style: const TextStyle(
              fontSize: 12, color: _secondaryText, fontStyle: FontStyle.italic),
        ),
      DateQuestion() =>
        _IconLine(CupertinoIcons.calendar, 'Date'),
      TimeQuestion(:final duration) =>
        _IconLine(CupertinoIcons.clock, duration ? 'Duration' : 'Time'),
      RatingQuestion(:final ratingScaleLevel, :final iconType) =>
        _RatingLine(count: ratingScaleLevel, iconType: iconType),
      FileUploadQuestion() =>
        _IconLine(CupertinoIcons.arrow_up_doc, 'File upload'),
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
    if (options.isEmpty) {
      return const Text(
        'No options — tap Edit to add some.',
        style: TextStyle(
            fontSize: 12, color: _secondaryText, fontStyle: FontStyle.italic),
      );
    }

    const maxShown = 3;
    final shown = options.take(maxShown).toList();
    final overflow = options.length - maxShown;

    final leadingIcon = switch (type) {
      ChoiceType.radio => CupertinoIcons.circle,
      ChoiceType.checkbox => CupertinoIcons.square,
      ChoiceType.dropDown => CupertinoIcons.chevron_down_circle,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...shown.map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(leadingIcon, size: 14, color: _secondaryText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      o.value,
                      style: const TextStyle(fontSize: 13, color: _primaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              '+ $overflow more',
              style: const TextStyle(
                  fontSize: 12,
                  color: _secondaryText,
                  fontStyle: FontStyle.italic),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _separator)),
      ),
      child: const Text(
        'Answer',
        style: TextStyle(
            fontSize: 12, color: _secondaryText, fontStyle: FontStyle.italic),
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
    return Row(
      children: [
        Icon(icon, size: 15, color: _secondaryText),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12, color: _secondaryText, fontStyle: FontStyle.italic),
        ),
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
      RatingIconType.star => Icons.star_border_rounded,
      RatingIconType.heart => Icons.favorite_border_rounded,
      RatingIconType.thumbUp => Icons.thumb_up_outlined,
    };
    return Row(
      children: List.generate(
        count.clamp(1, 10),
        (_) => Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(icon, size: 18, color: _purple),
        ),
      ),
    );
  }
}
