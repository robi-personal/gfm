import 'package:flutter/material.dart';

import '../../../../../../../core/models/enums.dart';
import '../../../../../../../core/models/question_kind.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

// ── Row widgets for QuestionEditSheet ─────────────────────────────────────────

class QesAddRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QesAddRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.purple),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QesTypeRow extends StatelessWidget {
  final QuestionKind kind;
  final VoidCallback onTap;
  const QesTypeRow({super.key, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(kind);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(kind), color: color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _typeLabel(kind),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 22, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class QesToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const QesToggleRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.meta.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.purple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class QesPointsRow extends StatelessWidget {
  final TextEditingController controller;
  const QesPointsRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Points',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Score awarded for a correct answer',
                  style: AppTextStyles.meta.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.groupedBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.purple, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type icon/color/label helpers ─────────────────────────────────────────────
// Same mapping as TypePickerSheet so the edit sheet and the picker stay
// visually consistent.

IconData _typeIcon(QuestionKind k) => switch (k) {
      TextQuestion(:final paragraph) =>
        paragraph ? Icons.notes : Icons.short_text,
      ChoiceQuestion(:final type) => switch (type) {
          ChoiceType.radio => Icons.radio_button_checked,
          ChoiceType.checkbox => Icons.check_box,
          ChoiceType.dropDown => Icons.expand_circle_down_outlined,
        },
      ScaleQuestion() => Icons.linear_scale,
      DateQuestion() => Icons.calendar_today,
      TimeQuestion(:final duration) =>
        duration ? Icons.timer_outlined : Icons.schedule,
      RatingQuestion() => Icons.star_rate_rounded,
      RowQuestion() => Icons.grid_view,
      FileUploadQuestion() => Icons.cloud_upload_outlined,
    };

Color _typeColor(QuestionKind k) => switch (k) {
      TextQuestion() => const Color(0xFF1A73E8),
      ChoiceQuestion() => AppColors.success,
      ScaleQuestion() => const Color(0xFFFBBC04),
      DateQuestion() || TimeQuestion() => const Color(0xFFEA4335),
      RatingQuestion() => const Color(0xFFFA7B17),
      RowQuestion() || FileUploadQuestion() => AppColors.purple,
    };

String _typeLabel(QuestionKind k) => switch (k) {
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
