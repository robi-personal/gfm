import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/question_kind.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Read-only preview of a question's answer area, shown inside [QuestionCard].
class QuestionCardPreview extends StatelessWidget {
  final QuestionKind kind;
  final dynamic grading;
  const QuestionCardPreview({super.key, required this.kind, this.grading});

  @override
  Widget build(BuildContext context) {
    final correctValues = grading != null
        ? ((grading.correctAnswers?.answers ?? []) as List)
            .map((a) => a.value as String)
            .toSet()
        : <String>{};

    return switch (kind) {
      ChoiceQuestion(:final options, :final type) =>
        _OptionsPreview(options: options, type: type, correctValues: correctValues),
      TextQuestion() when correctValues.isNotEmpty => Text(
          'Answer: ${correctValues.first}',
          style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.normal),
        ),
      TextQuestion(:final paragraph) => _PreviewLine(
          paragraph ? 'Long answer text' : 'Short answer text'),
      ScaleQuestion(:final low, :final high) => Text(
          'Scale $low – $high',
          style: AppTextStyles.meta.copyWith(
              fontWeight: FontWeight.normal, fontStyle: FontStyle.italic),
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
  final Set<String> correctValues;
  const _OptionsPreview({
    required this.options,
    required this.type,
    this.correctValues = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        'No options — tap Edit to add some.',
        style: AppTextStyles.meta.copyWith(
            fontWeight: FontWeight.normal, fontStyle: FontStyle.italic),
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
        ...shown.map((o) {
          final isCorrect = correctValues.contains(o.value);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(leadingIcon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          o.isOther ? 'Other...' : o.value,
                          style: AppTextStyles.meta.copyWith(
                            color: isCorrect ? AppColors.success : AppColors.textPrimary,
                            fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                            fontStyle: o.isOther ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCorrect) ...[
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.checkmark_alt,
                            size: 14, color: AppColors.success),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              '+ $overflow more',
              style: AppTextStyles.meta.copyWith(
                  fontWeight: FontWeight.normal,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'Answer',
        style: AppTextStyles.meta.copyWith(
            fontWeight: FontWeight.normal, fontStyle: FontStyle.italic),
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
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.meta.copyWith(
              fontWeight: FontWeight.normal, fontStyle: FontStyle.italic),
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
          child: Icon(icon, size: 18, color: AppColors.purple),
        ),
      ),
    );
  }
}
