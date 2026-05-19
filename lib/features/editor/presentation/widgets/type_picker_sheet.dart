import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/question_kind.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom sheet for picking a question type.
/// Returns the selected [QuestionKind] via [Navigator.pop], or nothing on dismiss.
class TypePickerSheet extends StatelessWidget {
  final QuestionKind current;

  const TypePickerSheet({super.key, required this.current});

  static Future<QuestionKind?> show(
      BuildContext context, QuestionKind current) {
    return showModalBottomSheet<QuestionKind>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TypePickerSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Question type',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Section('Common', [
                  _TypeTile(
                    label: 'Short answer',
                    description: 'Single line text response',
                    kind: const TextQuestion(paragraph: false),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Paragraph',
                    description: 'Multi-line text response',
                    kind: const TextQuestion(paragraph: true),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Multiple choice',
                    description: 'Pick one from a list',
                    kind: ChoiceQuestion(
                        type: ChoiceType.radio, options: _defaultOptions()),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Checkboxes',
                    description: 'Pick any number from a list',
                    kind: ChoiceQuestion(
                        type: ChoiceType.checkbox, options: _defaultOptions()),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Dropdown',
                    description: 'Pick one from a menu',
                    kind: ChoiceQuestion(
                        type: ChoiceType.dropDown, options: _defaultOptions()),
                    current: current,
                  ),
                ]),
                _Section('Advanced', [
                  _TypeTile(
                    label: 'Linear scale',
                    description: 'Rate on a numeric scale',
                    kind: const ScaleQuestion(low: 1, high: 5),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Date',
                    description: 'Pick a calendar date',
                    kind: const DateQuestion(),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Time',
                    description: 'Pick a time of day',
                    kind: const TimeQuestion(duration: false),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Duration',
                    description: 'Hours, minutes, seconds',
                    kind: const TimeQuestion(duration: true),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Rating',
                    description: 'Star or icon rating',
                    kind: const RatingQuestion(
                        ratingScaleLevel: 5, iconType: RatingIconType.star),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'File upload',
                    description: 'Created via Google Forms web editor',
                    kind: const FileUploadQuestion(),
                    current: current,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<ChoiceOption> _defaultOptions() => [];

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.iconInactive,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String label;
  final String description;
  final QuestionKind kind;
  final QuestionKind current;

  const _TypeTile({
    required this.label,
    required this.description,
    required this.kind,
    required this.current,
  });

  bool get _isSelected => _kindKey(kind) == _kindKey(current);

  @override
  Widget build(BuildContext context) {
    final color = _iconColor(kind);
    final icon = _iconFor(kind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: _isSelected ? AppColors.purpleTint : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(kind),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                // Colored icon box
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
                // Label + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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

IconData _iconFor(QuestionKind k) => switch (k) {
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

Color _iconColor(QuestionKind k) => switch (k) {
      TextQuestion() => const Color(0xFF1A73E8),
      ChoiceQuestion() => AppColors.success,
      ScaleQuestion() => const Color(0xFFFBBC04),
      DateQuestion() || TimeQuestion() => const Color(0xFFEA4335),
      RatingQuestion() => const Color(0xFFFA7B17),
      RowQuestion() || FileUploadQuestion() => AppColors.purple,
    };

String _kindKey(QuestionKind k) => switch (k) {
      TextQuestion(:final paragraph) => 'text_$paragraph',
      ChoiceQuestion(:final type) => 'choice_${type.name}',
      ScaleQuestion() => 'scale',
      DateQuestion() => 'date',
      TimeQuestion(:final duration) => 'time_$duration',
      RatingQuestion() => 'rating',
      RowQuestion() => 'row',
      FileUploadQuestion() => 'fileUpload',
    };
