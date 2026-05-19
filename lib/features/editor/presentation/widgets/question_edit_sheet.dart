import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/grading.dart' as grading_model;
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question_kind.dart';
import '../cubit/editor_cubit.dart';
import 'type_picker_sheet.dart';
import '../../../../core/theme/app_colors.dart';

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
  late List<bool> _isOtherOption;

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
    _isOtherOption = [];
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
    _isOtherOption = options.map((o) => o.isOther).toList();
  }

  void _disposeOptionCtrls() {
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _optionCtrls = [];
    _optionGoTos = [];
    _isOtherOption = [];
  }

  static String? _encodeGoTo(ChoiceOption opt) {
    if (opt.goToSectionId != null) return opt.goToSectionId;
    if (opt.goToAction != null) return opt.goToAction!.toJson();
    return null;
  }

  Future<void> _pickType() async {
    final picked = await TypePickerSheet.show(context, _kind);
    if (picked == null || !mounted) return;

    // File upload can't be created via the Forms API. Signal the editor to
    // open the Google Forms web editor instead, and close this sheet without
    // applying the change.
    if (picked is FileUploadQuestion) {
      context.read<EditorCubit>().requestFileUploadViaWeb();
      Navigator.of(context).pop();
      return;
    }

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
      final otherIndex = _isOtherOption.indexOf(true);
      final insertAt = otherIndex == -1 ? _optionCtrls.length : otherIndex;
      _optionCtrls.insert(
        insertAt,
        TextEditingController(text: 'Option ${_optionCtrls.length + 1}'),
      );
      _optionGoTos.insert(insertAt, null);
      _isOtherOption.insert(insertAt, false);
      _correctOptionIndices = _correctOptionIndices
          .map((i) => i >= insertAt ? i + 1 : i)
          .toSet();
    });
  }

  bool get _hasOtherOption => _isOtherOption.contains(true);

  void _addOtherOption() {
    if (_hasOtherOption) return;
    setState(() {
      _optionCtrls.add(TextEditingController(text: ''));
      _optionGoTos.add(null);
      _isOtherOption.add(true);
    });
  }

  void _removeOption(int i) {
    setState(() {
      _optionCtrls[i].dispose();
      _optionCtrls.removeAt(i);
      _optionGoTos.removeAt(i);
      _isOtherOption.removeAt(i);
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
          isOther: _isOtherOption[i],
          goToAction: goToAction,
          goToSectionId: goToSectionId,
        );
      });
      final nonEmpty =
          options.where((o) => o.value.isNotEmpty || o.isOther).toList();
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

  // Borderless decoration for fields embedded in a _Card (the card itself
  // provides the visual container, so the input doesn't need its own).
  static InputDecoration _bareDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15, color: AppColors.textTertiary),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      );

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeArea = MediaQuery.of(context).padding.bottom;
    final bottom = viewInsets + safeArea;

    const bodyStyle = TextStyle(fontSize: 15, color: Colors.black87);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit question',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _commit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          // Scrollable body — iOS-style grouped sections
          Flexible(
            child: ColoredBox(
              color: AppColors.groupedBackground,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── CONTENT ───────────────────────────────────────────
                    const _SectionLabel('Content'),
                    _Card(
                      child: Column(
                        children: [
                          _FieldBlock(
                            label: 'Title',
                            child: TextField(
                              controller: _titleCtrl,
                              style: bodyStyle.copyWith(
                                  fontWeight: FontWeight.w500),
                              decoration: _bareDec('e.g. What is your name?'),
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const _CardDivider(),
                          _FieldBlock(
                            label: 'Description',
                            child: TextField(
                              controller: _descCtrl,
                              style: bodyStyle,
                              decoration: _bareDec('Optional'),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── TYPE ──────────────────────────────────────────────
                    const _SectionLabel('Type'),
                    _Card(
                      child: _TypeRow(kind: _kind, onTap: _pickType),
                    ),
                    const SizedBox(height: 18),
                    // ── OPTIONS / PREVIEW ─────────────────────────────────
                    if (_kind is ChoiceQuestion) ...[
                      _SectionLabel(
                        widget.isQuiz
                            ? 'Options · tap ✓ to mark correct'
                            : 'Options',
                      ),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildOptionRows(context),
                              ),
                            ),
                            const _CardDivider(),
                            _AddRow(
                              icon: Icons.add_circle_outline,
                              label: 'Add option',
                              onTap: _addOption,
                            ),
                            if (!_hasOtherOption) ...[
                              const _CardDivider(),
                              _AddRow(
                                icon: Icons.add_box_outlined,
                                label: 'Add "Other"',
                                onTap: _addOtherOption,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      const _SectionLabel('Preview'),
                      _Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          child: _TypePreview(kind: _kind),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    // ── SETTINGS ──────────────────────────────────────────
                    const _SectionLabel('Settings'),
                    _Card(
                      child: Column(
                        children: [
                          _ToggleRow(
                            label: 'Required',
                            subtitle: 'Users must answer this question',
                            value: _required,
                            onChanged: (v) =>
                                setState(() => _required = v),
                          ),
                          if (widget.isQuiz) ...[
                            const _CardDivider(),
                            _PointsRow(controller: _pointsCtrl),
                          ],
                        ],
                      ),
                    ),
                    // ── QUIZ ANSWER & FEEDBACK ───────────────────────────
                    if (widget.isQuiz) ...[
                      const SizedBox(height: 18),
                      const _SectionLabel('Answer & feedback'),
                      _Card(
                        child: Column(
                          children: [
                            if (_kind is TextQuestion) ...[
                              _FieldBlock(
                                label: 'Correct answer',
                                child: TextField(
                                  controller: _correctTextCtrl,
                                  style: bodyStyle,
                                  decoration: _bareDec('Correct answer'),
                                ),
                              ),
                              const _CardDivider(),
                              _FieldBlock(
                                label: 'General feedback',
                                child: TextField(
                                  controller: _generalFeedbackCtrl,
                                  style: bodyStyle,
                                  decoration: _bareDec('Optional'),
                                  minLines: 1,
                                  maxLines: 3,
                                ),
                              ),
                            ] else if (_kind is ChoiceQuestion &&
                                _correctOptionIndices.isNotEmpty) ...[
                              _FieldBlock(
                                label: 'When correct',
                                child: TextField(
                                  controller: _whenRightCtrl,
                                  style: bodyStyle,
                                  decoration: _bareDec('Optional'),
                                  minLines: 1,
                                  maxLines: 3,
                                ),
                              ),
                              const _CardDivider(),
                              _FieldBlock(
                                label: 'When incorrect',
                                child: TextField(
                                  controller: _whenWrongCtrl,
                                  style: bodyStyle,
                                  decoration: _bareDec('Optional'),
                                  minLines: 1,
                                  maxLines: 3,
                                ),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                child: Text(
                                  'Mark a correct option above to add feedback.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
      final isCorrect = _correctOptionIndices.contains(i);
      final isLast = i == _optionCtrls.length - 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (widget.isQuiz) ...[
                  GestureDetector(
                    onTap: () => _toggleCorrectOption(i),
                    child: Icon(
                      isCorrect
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 22,
                      color: isCorrect ? AppColors.success : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Icon(icon, size: 19, color: AppColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: _isOtherOption[i]
                      ? const Text(
                          'Other…',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : TextField(
                          controller: _optionCtrls[i],
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            hintStyle: const TextStyle(
                                fontSize: 15, color: AppColors.textTertiary),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                ),
                if (_optionCtrls.length > 1)
                  GestureDetector(
                    onTap: () => _removeOption(i),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(Icons.close,
                          size: 18, color: AppColors.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          if (showGoTo)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _GoToDropdown(
                sections: widget.sections,
                value: _optionGoTos[i],
                onChanged: (v) => setState(() => _optionGoTos[i] = v),
              ),
            ),
          if (!isLast)
            const Divider(height: 1, color: AppColors.separator),
        ],
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

// ── Card / section helpers ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14),
      child: Divider(height: 1, color: AppColors.separator),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddRow({
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
              style: const TextStyle(
                fontSize: 15,
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

class _TypeRow extends StatelessWidget {
  final QuestionKind kind;
  final VoidCallback onTap;
  const _TypeRow({required this.kind, required this.onTap});

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
                style: const TextStyle(
                  fontSize: 15,
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

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _PointsRow extends StatelessWidget {
  final TextEditingController controller;
  const _PointsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Points',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Score awarded for a correct answer',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
              style: const TextStyle(
                fontSize: 15,
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

// Type icon/color/label helpers — same mapping as TypePickerSheet so the
// edit sheet and the picker stay visually consistent.
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
