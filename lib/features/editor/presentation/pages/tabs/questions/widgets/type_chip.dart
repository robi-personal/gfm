import 'package:flutter/material.dart';

import '../../../../../../../core/models/enums.dart';
import '../../../../../../../core/models/question_kind.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

/// Small pill showing the question type label.
/// Set [showCaret] to true to add a dropdown arrow (tap to change type).
class TypeChip extends StatelessWidget {
  final QuestionKind kind;
  final bool showCaret;

  const TypeChip({super.key, required this.kind, this.showCaret = false});

  @override
  Widget build(BuildContext context) {
    final label = _label(kind);
    final color = _color(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          if (showCaret) ...{
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: color),
          },
        ],
      ),
    );
  }

  static String _label(QuestionKind kind) => switch (kind) {
        TextQuestion(:final paragraph) =>
          paragraph ? 'Paragraph' : 'Short answer',
        ChoiceQuestion(:final type) => switch (type) {
            ChoiceType.radio => 'Multiple choice',
            ChoiceType.checkbox => 'Checkboxes',
            ChoiceType.dropDown => 'Dropdown',
          },
        ScaleQuestion() => 'Linear scale',
        DateQuestion() => 'Date',
        TimeQuestion(:final duration) => duration ? 'Duration' : 'Time',
        RatingQuestion() => 'Rating',
        RowQuestion() => 'Row',
        FileUploadQuestion() => 'File upload',
      };

  // App-native chip palette — deliberately distinct from Google's brand
  // blue/red/yellow/green so question types read as part of our own design
  // language rather than Google Forms.
  static Color _color(QuestionKind kind) => switch (kind) {
        TextQuestion() => AppColors.purple600,
        ChoiceQuestion() => const Color(0xFF0E9F8E), // teal
        ScaleQuestion() => const Color(0xFFD97706), // amber
        DateQuestion() || TimeQuestion() => const Color(0xFFDB2777), // rose
        RatingQuestion() => const Color(0xFFE0552E), // coral
        RowQuestion() || FileUploadQuestion() => const Color(0xFF64748B), // slate
      };
}
