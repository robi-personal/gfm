import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/models/enums.dart';
import '../../../../../../../core/models/question_kind.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

class TypeTile extends StatelessWidget {
  final String label;
  final String description;
  final QuestionKind kind;
  final QuestionKind current;

  const TypeTile({
    super.key,
    required this.label,
    required this.description,
    required this.kind,
    required this.current,
  });

  bool get _isSelected => kindKey(kind) == kindKey(current);

  @override
  Widget build(BuildContext context) {
    final color = iconColor(kind);
    final icon = iconFor(kind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: _isSelected ? AppColors.purpleTint : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(kind),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isSelected
                    ? AppColors.purple.withValues(alpha: 0.4)
                    : AppColors.separator,
                width: _isSelected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTextStyles.meta.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData iconFor(QuestionKind k) => switch (k) {
      TextQuestion(:final paragraph) =>
        paragraph ? CupertinoIcons.text_alignleft : CupertinoIcons.minus,
      ChoiceQuestion(:final type) => switch (type) {
          ChoiceType.radio => CupertinoIcons.smallcircle_circle,
          ChoiceType.checkbox => CupertinoIcons.checkmark_square,
          ChoiceType.dropDown => CupertinoIcons.chevron_down_square,
        },
      ScaleQuestion() => CupertinoIcons.slider_horizontal_3,
      DateQuestion() => CupertinoIcons.calendar,
      TimeQuestion(:final duration) =>
        duration ? CupertinoIcons.timer : CupertinoIcons.clock,
      RatingQuestion() => CupertinoIcons.star_fill,
      RowQuestion() => CupertinoIcons.square_grid_2x2,
      FileUploadQuestion() => CupertinoIcons.arrow_up_doc,
    };

Color iconColor(QuestionKind k) => switch (k) {
      TextQuestion() => const Color(0xFF1A73E8),
      ChoiceQuestion() => AppColors.success,
      ScaleQuestion() => const Color(0xFFFBBC04),
      DateQuestion() || TimeQuestion() => const Color(0xFFEA4335),
      RatingQuestion() => const Color(0xFFFA7B17),
      RowQuestion() || FileUploadQuestion() => AppColors.purple,
    };

String kindKey(QuestionKind k) => switch (k) {
      TextQuestion(:final paragraph) => 'text_$paragraph',
      ChoiceQuestion(:final type) => 'choice_${type.name}',
      ScaleQuestion() => 'scale',
      DateQuestion() => 'date',
      TimeQuestion(:final duration) => 'time_$duration',
      RatingQuestion() => 'rating',
      RowQuestion() => 'row',
      FileUploadQuestion() => 'fileUpload',
    };
