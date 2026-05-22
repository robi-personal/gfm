import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/choice_option.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/grading.dart' as grading_model;
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question_kind.dart';
import '../cubit/editor_cubit.dart';
import 'question_edit_rows.dart';
import 'question_file_upload_prompt.dart';
import 'type_picker_sheet.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuestionEditSheet extends StatefulWidget {
  final Item item;

  /// Page-break items from the form — used to populate branching dropdowns.
  final List<Item> sections;

  /// Whether the form is in quiz mode — shows the Points field when true.
  final bool isQuiz;

  /// True when adding a brand-new question. Done commits the draft to the
  /// form; dismissing the sheet discards it (so accidental + taps don't
  /// leave placeholders behind).
  final bool isDraft;

  const QuestionEditSheet({
    super.key,
    required this.item,
    required this.sections,
    required this.isQuiz,
    this.isDraft = false,
  });

  static Future<void> show(
    BuildContext context,
    Item item,
    List<Item> sections, {
    required bool isQuiz,
    bool isDraft = false,
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
        child: QuestionEditSheet(
          item: item,
          sections: sections,
          isQuiz: isQuiz,
          isDraft: isDraft,
        ),
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

  // True after the user picks "File upload" in the type picker — swaps the
  // sheet body for an in-sheet confirmation panel so they can back out
  // without losing their question state.
  bool _showFileUploadPrompt = false;

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

    // File upload can't be created via the Forms API. Show an in-sheet
    // explainer panel so the user can confirm or back out without losing
    // the question they were editing.
    if (picked is FileUploadQuestion) {
      setState(() => _showFileUploadPrompt = true);
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
    // DROPDOWN doesn't support Other — strip isOther options.
    final stripped = next.type == ChoiceType.dropDown
        ? oldOpts.where((o) => !o.isOther).toList()
        : oldOpts;
    final opts = next.type == ChoiceType.checkbox
        ? stripped.map((o) => ChoiceOption(value: o.value)).toList()
        : stripped;
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

    // Only set grading when the form is in quiz mode. Sending grading on a
    // non-quiz form is rejected by the API: "Invalid grading, grading cannot
    // be set on a form that has no grading settings." We intentionally drop
    // any pre-existing grading the question may carry from when the form
    // was previously in quiz mode.
    grading_model.Grading? grading;
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
    if (widget.isDraft) {
      context.read<EditorCubit>().addQuestionFromDraft(updatedItem);
    } else {
      context.read<EditorCubit>().updateItemFull(updatedItem);
    }
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildHeader(context),
          const Divider(height: 1, color: AppColors.borderSubtle),
          Flexible(
            child: ColoredBox(
              color: AppColors.groupedBackground,
              child: _showFileUploadPrompt
                  ? _buildFileUploadPrompt(context)
                  : _buildScrollBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _showFileUploadPrompt ? 'Add file upload' : 'Edit question',
              style: AppTextStyles.screenHeader.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          if (!_showFileUploadPrompt)
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
    );
  }

  Widget _buildFileUploadPrompt(BuildContext context) {
    return QuestionFileUploadPrompt(
      onCancel: () => setState(() => _showFileUploadPrompt = false),
      onContinue: () {
        context.read<EditorCubit>().requestFileUploadViaWeb();
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildScrollBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTypeSection(),
          const SizedBox(height: 18),
          _buildContentSection(context),
          const SizedBox(height: 18),
          _buildOptionsOrPreviewSection(context),
          _buildSettingsSection(),
          if (widget.isQuiz) ...[
            const SizedBox(height: 18),
            _buildQuizFeedbackSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Type'),
        _Card(child: QesTypeRow(kind: _kind, onTap: _pickType)),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final bodyStyle = AppTextStyles.body.copyWith(color: Colors.black87);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Content'),
        _Card(
          child: Column(
            children: [
              _FieldBlock(
                label: 'Title',
                child: TextField(
                  controller: _titleCtrl,
                  style: bodyStyle.copyWith(fontWeight: FontWeight.w500),
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
      ],
    );
  }

  Widget _buildOptionsOrPreviewSection(BuildContext context) {
    if (_kind is ChoiceQuestion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            widget.isQuiz ? 'Options · tap ✓ to mark correct' : 'Options',
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
                QesAddRow(
                  icon: Icons.add_circle_outline,
                  label: 'Add option',
                  onTap: _addOption,
                ),
                if (!_hasOtherOption &&
                    (_kind as ChoiceQuestion).type != ChoiceType.dropDown) ...[
                  const _CardDivider(),
                  QesAddRow(
                    icon: Icons.add_box_outlined,
                    label: 'Add "Other"',
                    onTap: _addOtherOption,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Preview'),
        _Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: _TypePreview(kind: _kind),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Settings'),
        _Card(
          child: Column(
            children: [
              QesToggleRow(
                label: 'Required',
                subtitle: 'Users must answer this question',
                value: _required,
                onChanged: (v) => setState(() => _required = v),
              ),
              if (widget.isQuiz) ...[
                const _CardDivider(),
                QesPointsRow(controller: _pointsCtrl),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizFeedbackSection(BuildContext context) {
    final bodyStyle = AppTextStyles.body.copyWith(color: Colors.black87);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Text(
                    'Mark a correct option above to add feedback.',
                    style: AppTextStyles.meta.copyWith(
                        fontWeight: FontWeight.normal),
                  ),
                ),
            ],
          ),
        ),
      ],
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
                      ? Text(
                          'Other…',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : TextField(
                          controller: _optionCtrls[i],
                          style: AppTextStyles.body.copyWith(
                              color: AppColors.textPrimary),
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
        style: AppTextStyles.sectionLabel.copyWith(
          letterSpacing: 0.6,
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
            style: AppTextStyles.sectionLabel.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

