import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question.dart';
import '../../../../core/models/question_kind.dart';
import '../cubit/editor_cubit.dart';
import 'question_card_preview.dart';
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

  Widget _buildSingle(BuildContext context, Question question) {
    final kind = question.kind;
    final isRequired = question.required;

    return _CardShell(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left purple accent bar — full card height including drag handle
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // Right column: drag handle + card content
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DragHandleHint(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: item.title?.isNotEmpty == true
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TypeChip(kind: kind),
                      ],
                    ),
                    if (item.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: AppTextStyles.meta.copyWith(
                            fontWeight: FontWeight.normal),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // ── Content preview ───────────────────────────────────
                    QuestionCardPreview(
                      kind: kind,
                      grading: isQuiz ? question.grading : null,
                    ),
                    // ── "Add Option" link (choice questions only) ─────────
                    if (kind is ChoiceQuestion) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => QuestionEditSheet.show(
                          context, item, sections,
                          isQuiz: isQuiz,
                        ),
                        child: Text(
                          kind.type == ChoiceType.dropDown
                              ? 'Add Option'
                              : 'Add Option  ·  Add "Other"',
                          style: AppTextStyles.meta.copyWith(
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                    ],
                    if (isQuiz && question.grading != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Points: ${question.grading!.pointValue}',
                          style: AppTextStyles.meta.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.separator),
                    const SizedBox(height: 12),
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
                        // Edit — file-upload questions route through the
                        // Google Forms web editor (API doesn't support them).
                        _ActionButton(
                          icon: CupertinoIcons.pencil,
                          tooltip: 'Edit',
                          onPressed: () {
                            if (kind is FileUploadQuestion) {
                              context
                                  .read<EditorCubit>()
                                  .requestEditFileUploadViaWeb();
                            } else {
                              QuestionEditSheet.show(
                                context, item, sections,
                                isQuiz: isQuiz,
                              );
                            }
                          },
                        ),
                        const Spacer(),
                        // Required toggle — not available for read-only question types
                        if (kind is! FileUploadQuestion) ...[
                          const Text(
                            'Required',
                            style: AppTextStyles.meta,
                          ),
                          const SizedBox(width: 6),
                          Transform.scale(
                            scale: 0.75,
                            child: CupertinoSwitch(
                              value: isRequired,
                              activeTrackColor: AppColors.purple,
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
                      ],
                    ),
                  ],
                ),
              ),
                ],
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
                color: AppColors.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DragHandleHint(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
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
                            style: AppTextStyles.meta.copyWith(
                                fontWeight: FontWeight.normal),
                          ),
                        ],
                        const Divider(height: 20, color: AppColors.separator),
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
                ],
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

class DragHandleHint extends StatelessWidget {
  const DragHandleHint({super.key});

  static const _dot = BoxDecoration(
    color: AppColors.iconInactive,
    shape: BoxShape.circle,
  );

  Widget _dotBox() => Container(
        width: 3,
        height: 3,
        decoration: _dot,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dotBox(),
              const SizedBox(height: 3),
              _dotBox(),
              const SizedBox(height: 3),
              _dotBox(),
            ],
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dotBox(),
              const SizedBox(height: 3),
              _dotBox(),
              const SizedBox(height: 3),
              _dotBox(),
            ],
          ),
        ],
      ),
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
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          margin: const EdgeInsets.only(right: 8, bottom: 6),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.purple),
        ),
      ),
    );
  }
}


