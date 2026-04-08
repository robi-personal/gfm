import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/question_kind.dart';

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
            style: TextStyle(
              fontSize: 11,
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

  static Color _color(QuestionKind kind) => switch (kind) {
        TextQuestion() => const Color(0xFF1A73E8),
        ChoiceQuestion() => const Color(0xFF34A853),
        ScaleQuestion() => const Color(0xFFFBBC04),
        DateQuestion() || TimeQuestion() => const Color(0xFFEA4335),
        RatingQuestion() => const Color(0xFFFA7B17),
        RowQuestion() || FileUploadQuestion() => Colors.grey,
      };
}
