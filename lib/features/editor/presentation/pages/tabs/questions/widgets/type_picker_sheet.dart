import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/models/choice_option.dart';
import '../../../../../../../core/models/enums.dart';
import '../../../../../../../core/models/question_kind.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';
import 'type_tile.dart';

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
                Expanded(
                  child: Text(
                    'Question type',
                    style: AppTextStyles.screenHeader.copyWith(
                      fontSize: 20,
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
                  TypeTile(
                    label: 'Short answer',
                    description: 'Single line text response',
                    kind: const TextQuestion(paragraph: false),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Paragraph',
                    description: 'Multi-line text response',
                    kind: const TextQuestion(paragraph: true),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Multiple choice',
                    description: 'Pick one from a list',
                    kind: ChoiceQuestion(
                        type: ChoiceType.radio, options: _defaultOptions()),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Checkboxes',
                    description: 'Pick any number from a list',
                    kind: ChoiceQuestion(
                        type: ChoiceType.checkbox, options: _defaultOptions()),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Dropdown',
                    description: 'Pick one from a menu',
                    kind: ChoiceQuestion(
                        type: ChoiceType.dropDown, options: _defaultOptions()),
                    current: current,
                  ),
                ]),
                _Section('Advanced', [
                  TypeTile(
                    label: 'Linear scale',
                    description: 'Rate on a numeric scale',
                    kind: const ScaleQuestion(low: 1, high: 5),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Date',
                    description: 'Pick a calendar date',
                    kind: const DateQuestion(),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Time',
                    description: 'Pick a time of day',
                    kind: const TimeQuestion(duration: false),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Duration',
                    description: 'Hours, minutes, seconds',
                    kind: const TimeQuestion(duration: true),
                    current: current,
                  ),
                  TypeTile(
                    label: 'Rating',
                    description: 'Star or icon rating',
                    kind: const RatingQuestion(
                        ratingScaleLevel: 5, iconType: RatingIconType.star),
                    current: current,
                  ),
                  TypeTile(
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
            style: AppTextStyles.sectionLabel.copyWith(
              letterSpacing: 0.6,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
