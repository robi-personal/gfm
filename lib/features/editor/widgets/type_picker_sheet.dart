import 'package:flutter/material.dart';

import '../../../core/models/choice_option.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/question_kind.dart';
import 'type_chip.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TypePickerSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          const _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Question type',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _Section('Free-tier types', [
                  _TypeTile(
                    label: 'Short answer',
                    kind: const TextQuestion(paragraph: false),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Paragraph',
                    kind: const TextQuestion(paragraph: true),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Multiple choice',
                    kind: ChoiceQuestion(
                        type: ChoiceType.radio, options: _defaultOptions()),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Checkboxes',
                    kind: ChoiceQuestion(
                        type: ChoiceType.checkbox, options: _defaultOptions()),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Dropdown',
                    kind: ChoiceQuestion(
                        type: ChoiceType.dropDown, options: _defaultOptions()),
                    current: current,
                  ),
                ]),
                _Section('Advanced types', [
                  _TypeTile(
                    label: 'Linear scale',
                    kind: const ScaleQuestion(low: 1, high: 5),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Date',
                    kind: const DateQuestion(),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Time',
                    kind: const TimeQuestion(duration: false),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Duration',
                    kind: const TimeQuestion(duration: true),
                    current: current,
                  ),
                  _TypeTile(
                    label: 'Rating',
                    kind: const RatingQuestion(
                        ratingScaleLevel: 5, iconType: RatingIconType.star),
                    current: current,
                  ),
                ]),
                const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        ...children,
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  final String label;
  final QuestionKind kind;
  final QuestionKind current;

  const _TypeTile(
      {required this.label, required this.kind, required this.current});

  bool get _isSelected => _kindKey(kind) == _kindKey(current);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: TypeChip(kind: kind),
      title: Text(label),
      selected: _isSelected,
      trailing: _isSelected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(kind),
    );
  }
}

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
