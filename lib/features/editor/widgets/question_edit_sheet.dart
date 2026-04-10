import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/choice_option.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/grading.dart' as grading_model;
import '../../../core/models/item.dart';
import '../../../core/models/item_content.dart';
import '../../../core/models/question_kind.dart';
import '../editor_cubit.dart';
import 'type_chip.dart';
import 'type_picker_sheet.dart';

class QuestionEditSheet extends StatefulWidget {
  final Item item;

  /// Page-break items from the form — used to populate branching dropdowns.
  final List<Item> sections;

  /// Whether the form is in quiz mode — shows the Points field when true.
  final bool isQuiz;

  const QuestionEditSheet({
    super.key,
    required this.item,
    required this.sections,
    required this.isQuiz,
  });

  static Future<void> show(
    BuildContext context,
    Item item,
    List<Item> sections, {
    required bool isQuiz,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<EditorCubit>(),
        child: QuestionEditSheet(item: item, sections: sections, isQuiz: isQuiz),
      ),
    );
  }

  @override
  State<QuestionEditSheet> createState() => _QuestionEditSheetState();
}

class _QuestionEditSheetState extends State<QuestionEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _pointsCtrl;
  late QuestionKind _kind;
  late bool _required;
  late List<TextEditingController> _optionCtrls;
  late List<String?> _optionGoTos;

  // Quiz grading state
  late Set<int> _correctOptionIndices; // ChoiceQuestion: which option indices are correct
  late final TextEditingController _correctTextCtrl;  // TextQuestion correct answer
  late final TextEditingController _whenRightCtrl;
  late final TextEditingController _whenWrongCtrl;
  late final TextEditingController _generalFeedbackCtrl;

  @override
  void initState() {
    super.initState();
    final content = widget.item.content as QuestionItemContent;
    final q = content.question;
    _titleCtrl = TextEditingController(text: widget.item.title ?? '');
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
    _pointsCtrl = TextEditingController(
      text: '${q.grading?.pointValue ?? 0}',
    );
    _kind = q.kind;
    _required = q.required;
    _optionCtrls = [];
    _optionGoTos = [];
    if (q.kind case ChoiceQuestion(:final options)) {
      _initOptionCtrls(options);
    }

    // Quiz grading
    final grading = q.grading;
    final correctValues =
        grading?.correctAnswers?.answers.map((a) => a.value).toSet() ?? {};
    _correctOptionIndices = {};
    if (q.kind case ChoiceQuestion(:final options)) {
      for (var i = 0; i < options.length; i++) {
        if (correctValues.contains(options[i].value)) {
          _correctOptionIndices.add(i);
        }
      }
    }
    _correctTextCtrl = TextEditingController(
      text: (q.kind is TextQuestion)
          ? (grading?.correctAnswers?.answers.firstOrNull?.value ?? '')
          : '',
    );
    _whenRightCtrl =
        TextEditingController(text: grading?.whenRight?.text ?? '');
    _whenWrongCtrl =
        TextEditingController(text: grading?.whenWrong?.text ?? '');
    _generalFeedbackCtrl =
        TextEditingController(text: grading?.generalFeedback?.text ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _pointsCtrl.dispose();
    _correctTextCtrl.dispose();
    _whenRightCtrl.dispose();
    _whenWrongCtrl.dispose();
    _generalFeedbackCtrl.dispose();
    _disposeOptionCtrls();
    super.dispose();
  }

  void _initOptionCtrls(List<ChoiceOption> options) {
    _disposeOptionCtrls();
    _optionCtrls =
        options.map((o) => TextEditingController(text: o.value)).toList();
    _optionGoTos = options.map(_encodeGoTo).toList();
  }

  void _disposeOptionCtrls() {
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _optionCtrls = [];
    _optionGoTos = [];
  }

  static String? _encodeGoTo(ChoiceOption opt) {
    if (opt.goToSectionId != null) return opt.goToSectionId;
    if (opt.goToAction != null) return opt.goToAction!.toJson();
    return null;
  }

  Future<void> _pickType() async {
    final picked = await TypePickerSheet.show(context, _kind);
    if (picked == null || !mounted) return;
    final merged = _mergeKind(_kind, picked);
    setState(() {
      _kind = merged;
      _correctOptionIndices = {};
      if (merged is ChoiceQuestion) {
        _initOptionCtrls(merged.options);
      } else {
        _disposeOptionCtrls();
      }
    });
  }

  QuestionKind _mergeKind(QuestionKind old, QuestionKind next) {
    if (next is! ChoiceQuestion) return next;
    final oldOpts = old is ChoiceQuestion && old.options.isNotEmpty
        ? old.options
        : [ChoiceOption(value: 'Option 1')];
    // CHECKBOX doesn't support branching — strip goTo data from options.
    final opts = next.type == ChoiceType.checkbox
        ? oldOpts.map((o) => ChoiceOption(value: o.value)).toList()
        : oldOpts;
    return next.copyWith(options: opts);
  }

  void _addOption() {
    setState(() {
      _optionCtrls.add(
        TextEditingController(text: 'Option ${_optionCtrls.length + 1}'),
      );
      _optionGoTos.add(null);
    });
  }

  void _removeOption(int i) {
    setState(() {
      _optionCtrls[i].dispose();
      _optionCtrls.removeAt(i);
      _optionGoTos.removeAt(i);
      // Remove and shift correct-answer indices.
      _correctOptionIndices = _correctOptionIndices
          .where((idx) => idx != i)
          .map((idx) => idx > i ? idx - 1 : idx)
          .toSet();
    });
  }

  void _toggleCorrectOption(int i) {
    final cq = _kind as ChoiceQuestion;
    setState(() {
      if (cq.type == ChoiceType.checkbox) {
        // Multi-select
        if (_correctOptionIndices.contains(i)) {
          _correctOptionIndices = {..._correctOptionIndices}..remove(i);
        } else {
          _correctOptionIndices = {..._correctOptionIndices, i};
        }
      } else {
        // Single-select (radio / dropdown)
        _correctOptionIndices = _correctOptionIndices.contains(i) ? {} : {i};
      }
    });
  }

  void _commit() {
    final content = widget.item.content as QuestionItemContent;
    final QuestionKind finalKind;

    if (_kind is ChoiceQuestion) {
      final cq = _kind as ChoiceQuestion;
      final options = List.generate(_optionCtrls.length, (i) {
        final goTo = _optionGoTos[i];
        GoToAction? goToAction;
        String? goToSectionId;
        if (goTo == 'NEXT_SECTION') {
          goToAction = GoToAction.nextSection;
        } else if (goTo == 'RESTART_FORM') {
          goToAction = GoToAction.restartForm;
        } else if (goTo == 'SUBMIT_FORM') {
          goToAction = GoToAction.submitForm;
        } else if (goTo != null) {
          goToSectionId = goTo;
        }
        return ChoiceOption(
          value: _optionCtrls[i].text,
          goToAction: goToAction,
          goToSectionId: goToSectionId,
        );
      });
      final nonEmpty =
          options.where((o) => o.value.isNotEmpty).toList();
      finalKind = cq.copyWith(
        options: nonEmpty.isEmpty
            ? [ChoiceOption(value: 'Option 1')]
            : nonEmpty,
      );
    } else {
      finalKind = _kind;
    }

    grading_model.Grading? grading = content.question.grading;
    if (widget.isQuiz) {
      final pts = int.tryParse(_pointsCtrl.text.trim()) ?? 0;

      grading_model.CorrectAnswers? correctAnswers;
      grading_model.Feedback? whenRight;
      grading_model.Feedback? whenWrong;
      grading_model.Feedback? generalFeedback;

      if (finalKind is ChoiceQuestion) {
        final cqFinal = finalKind;
        final correctOpts = _correctOptionIndices
            .where((i) => i < cqFinal.options.length)
            .map((i) => grading_model.CorrectAnswer(value: cqFinal.options[i].value))
            .toList();
        if (correctOpts.isNotEmpty) {
          correctAnswers = grading_model.CorrectAnswers(answers: correctOpts);
          final right = _whenRightCtrl.text.trim();
          final wrong = _whenWrongCtrl.text.trim();
          if (right.isNotEmpty) whenRight = grading_model.Feedback(text: right);
          if (wrong.isNotEmpty) whenWrong = grading_model.Feedback(text: wrong);
        }
      } else if (finalKind is TextQuestion) {
        final val = _correctTextCtrl.text.trim();
        if (val.isNotEmpty) {
          correctAnswers = grading_model.CorrectAnswers(
              answers: [grading_model.CorrectAnswer(value: val)]);
        }
        final gen = _generalFeedbackCtrl.text.trim();
        if (gen.isNotEmpty) generalFeedback = grading_model.Feedback(text: gen);
      }

      grading = grading_model.Grading(
        pointValue: pts,
        correctAnswers: correctAnswers,
        whenRight: whenRight,
        whenWrong: whenWrong,
        generalFeedback: generalFeedback,
      );
    }

    final updatedItem = widget.item.copyWith(
      title: _titleCtrl.text.isEmpty ? 'Question' : _titleCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      content: content.copyWith(
        question: content.question.copyWith(
          kind: finalKind,
          required: _required,
          grading: grading,
        ),
      ),
    );
    context.read<EditorCubit>().updateItemFull(updatedItem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Edit question',
                      style: theme.textTheme.titleMedium),
                ),
                FilledButton.tonal(
                  onPressed: _commit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: 'Question title',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  // Description
                  TextField(
                    controller: _descCtrl,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Type
                  Row(
                    children: [
                      Text('Type',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _pickType,
                        child: TypeChip(kind: _kind, showCaret: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Options or type preview
                  if (_kind is ChoiceQuestion) ...[
                    Row(
                      children: [
                        Text('Options',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        if (widget.isQuiz) ...[
                          const SizedBox(width: 8),
                          Text('— tap ✓ to mark correct',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._buildOptionRows(context),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: Icon(Icons.add, size: 16, color: cs.primary),
                      label: Text('Add option',
                          style: TextStyle(color: cs.primary)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ] else ...[
                    _TypePreview(kind: _kind),
                  ],
                  const Divider(height: 28),
                  // Required
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Required',
                          style: theme.textTheme.bodyMedium),
                      Switch(
                        value: _required,
                        onChanged: (v) => setState(() => _required = v),
                      ),
                    ],
                  ),
                  // Points (quiz mode only)
                  if (widget.isQuiz) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Points',
                            style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _pointsCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Correct answer (TextQuestion only)
                    if (_kind is TextQuestion) ...[
                      const SizedBox(height: 16),
                      Text('Answer key',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _correctTextCtrl,
                        style: theme.textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          labelText: 'Correct answer',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                    // Feedback
                    if (_kind is ChoiceQuestion &&
                        _correctOptionIndices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Feedback',
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _whenRightCtrl,
                        style: theme.textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          labelText: 'When correct (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _whenWrongCtrl,
                        style: theme.textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          labelText: 'When incorrect (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ] else if (_kind is TextQuestion) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _generalFeedbackCtrl,
                        style: theme.textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          labelText: 'General feedback (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptionRows(BuildContext context) {
    final cq = _kind as ChoiceQuestion;
    final showGoTo = widget.sections.isNotEmpty &&
        (cq.type == ChoiceType.radio || cq.type == ChoiceType.dropDown);
    final icon = switch (cq.type) {
      ChoiceType.radio => Icons.radio_button_unchecked,
      ChoiceType.checkbox => Icons.check_box_outline_blank,
      ChoiceType.dropDown => Icons.arrow_drop_down_circle_outlined,
    };

    return List.generate(_optionCtrls.length, (i) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final isCorrect = _correctOptionIndices.contains(i);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.isQuiz) ...[
                  GestureDetector(
                    onTap: () => _toggleCorrectOption(i),
                    child: Icon(
                      isCorrect
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 20,
                      color: isCorrect ? Colors.green : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(icon, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _optionCtrls[i],
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                if (_optionCtrls.length > 1)
                  GestureDetector(
                    onTap: () => _removeOption(i),
                    child: Icon(Icons.close,
                        size: 18, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
            if (showGoTo)
              _GoToDropdown(
                sections: widget.sections,
                value: _optionGoTos[i],
                onChanged: (v) => setState(() => _optionGoTos[i] = v),
              ),
          ],
        ),
      );
    });
  }
}

// ── Go-to dropdown ────────────────────────────────────────────────────────────

class _GoToDropdown extends StatelessWidget {
  final List<Item> sections;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GoToDropdown({
    required this.sections,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 2),
      child: DropdownButton<String?>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
        icon: Icon(Icons.arrow_drop_down, size: 16, color: cs.primary),
        hint: Text('Go to next section',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Go to next section',
                style: theme.textTheme.bodySmall),
          ),
          ...sections.map((s) => DropdownMenuItem<String?>(
                value: s.itemId,
                child: Text(
                  'Go to: ${s.title?.isNotEmpty == true ? s.title! : 'Section'}',
                  style: theme.textTheme.bodySmall,
                ),
              )),
          DropdownMenuItem<String?>(
            value: 'RESTART_FORM',
            child:
                Text('Restart form', style: theme.textTheme.bodySmall),
          ),
          DropdownMenuItem<String?>(
            value: 'SUBMIT_FORM',
            child:
                Text('Submit form', style: theme.textTheme.bodySmall),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ── Type preview (non-choice questions) ──────────────────────────────────────

class _TypePreview extends StatelessWidget {
  final QuestionKind kind;
  const _TypePreview({required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return switch (kind) {
      TextQuestion(:final paragraph) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Text(
            paragraph ? 'Long answer text' : 'Short answer text',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ScaleQuestion(:final low, :final high, :final lowLabel, :final highLabel) =>
        Row(children: [
          if (lowLabel != null)
            Text(lowLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                high - low + 1,
                (i) => Text('${low + i}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (highLabel != null)
            Text(highLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      RatingQuestion(:final ratingScaleLevel, :final iconType) => Row(
          children: List.generate(
            ratingScaleLevel.clamp(1, 10),
            (_) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                switch (iconType) {
                  RatingIconType.star => Icons.star_border,
                  RatingIconType.heart => Icons.favorite_border,
                  RatingIconType.thumbUp => Icons.thumb_up_outlined,
                },
                size: 22,
                color: cs.primary,
              ),
            ),
          ),
        ),
      DateQuestion() => _iconRow(context, Icons.calendar_today, 'Date'),
      TimeQuestion(:final duration) => _iconRow(
          context, Icons.access_time, duration ? 'Duration' : 'Time'),
      FileUploadQuestion() =>
        _iconRow(context, Icons.upload_file, 'File upload'),
      ChoiceQuestion() || RowQuestion() => const SizedBox.shrink(),
    };
  }

  Widget _iconRow(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Text(label,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic)),
    ]);
  }
}
