import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/generated_form.dart';
import '../cubit/ai_form_builder_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Preview screen — shown after a successful AI generation (§1.2 / §2.2).
/// Displays every generated question so the user can review before creating
/// the real Google Form. "Create Form" taps hand off to the cubit.
class AiFormPreviewPage extends StatelessWidget {
  const AiFormPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.read<AiFormBuilderCubit>().backFromPreview();
          Navigator.of(context).pop();
        }
      },
      child: BlocBuilder<AiFormBuilderCubit, AiFormBuilderState>(
        builder: (context, state) {
          final GeneratedForm? form;
          final bool isCreating;

          if (state is AiFormBuilderPreview) {
            form = state.form;
            isCreating = false;
          } else if (state is AiFormBuilderCreatingForm) {
            form = state.form;
            isCreating = true;
          } else {
            form = null;
            isCreating = false;
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Preview'),
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              leading: BackButton(
                onPressed: isCreating
                    ? null
                    : () {
                        context.read<AiFormBuilderCubit>().backFromPreview();
                        Navigator.of(context).pop();
                      },
              ),
            ),
            body: form == null
                ? const Center(child: CircularProgressIndicator())
                : _PreviewBody(form: form, isCreating: isCreating),
          );
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _PreviewBody extends StatelessWidget {
  final GeneratedForm form;
  final bool isCreating;

  const _PreviewBody({required this.form, required this.isCreating});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AiFormBuilderCubit>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Form header
                _FormHeader(form: form),
                const SizedBox(height: 20),

                // Question count
                Text(
                  '${form.questions.length} question${form.questions.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),

                // Question cards
                for (var i = 0; i < form.questions.length; i++) ...[
                  _QuestionCard(
                    index: i,
                    question: form.questions[i],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),

        // Create Form button — sticky at bottom
        _CreateFormBar(
          isCreating: isCreating,
          isQuiz: form.isQuiz,
          onTap: cubit.createForm,
        ),
      ],
    );
  }
}

// ── Form header ───────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  final GeneratedForm form;

  const _FormHeader({required this.form});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purpleTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.purple, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI-generated form',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            form.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (form.description != null && form.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              form.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final int index;
  final AiQuestion question;

  const _QuestionCard({required this.index, required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = _typeInfo(question.type);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type chip + required badge
            Row(
              children: [
                _TypeChip(label: label, icon: icon),
                const Spacer(),
                if (question.required)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Required',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Question number + title
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '${index + 1}. ',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  TextSpan(text: question.title),
                ],
              ),
            ),

            // Description
            if (question.description != null &&
                question.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                question.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Type-specific detail
            _TypeDetail(question: question),

            // Quiz: points (matches editor card design)
            if (question.grading != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Points: ${question.grading!.pointValue}',
                  style: AppTextStyles.meta.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static (String, IconData) _typeInfo(AiQuestionType type) {
    return switch (type) {
      AiQuestionType.shortAnswer => ('Short answer', Icons.short_text),
      AiQuestionType.paragraph => ('Paragraph', Icons.notes),
      AiQuestionType.multipleChoice =>
        ('Multiple choice', Icons.radio_button_checked),
      AiQuestionType.checkboxes => ('Checkboxes', Icons.check_box),
      AiQuestionType.dropdown => ('Dropdown', Icons.arrow_drop_down_circle),
      AiQuestionType.linearScale => ('Linear scale', Icons.linear_scale),
      AiQuestionType.date => ('Date', Icons.calendar_today),
      AiQuestionType.time => ('Time', Icons.access_time),
      AiQuestionType.rating => ('Rating', Icons.star),
    };
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TypeChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purpleTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.purple),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type-specific detail ──────────────────────────────────────────────────────

class _TypeDetail extends StatelessWidget {
  final AiQuestion question;

  const _TypeDetail({required this.question});

  @override
  Widget build(BuildContext context) {
    return switch (question.type) {
      AiQuestionType.multipleChoice ||
      AiQuestionType.checkboxes ||
      AiQuestionType.dropdown =>
        _OptionsDetail(question: question),
      AiQuestionType.linearScale => _ScaleDetail(question: question),
      AiQuestionType.rating => _RatingDetail(question: question),
      AiQuestionType.shortAnswer ||
      AiQuestionType.paragraph =>
        _CorrectAnswerDetail(question: question),
      _ => const SizedBox.shrink(),
    };
  }
}

class _OptionsDetail extends StatelessWidget {
  final AiQuestion question;

  const _OptionsDetail({required this.question});

  @override
  Widget build(BuildContext context) {
    final options = question.options;
    if (options == null || options.isEmpty) return const SizedBox.shrink();

    final defaultIcon = switch (question.type) {
      AiQuestionType.multipleChoice => Icons.radio_button_unchecked,
      AiQuestionType.checkboxes => Icons.check_box_outline_blank,
      _ => Icons.arrow_right, // dropdown
    };
    final correctSet = question.grading?.correctAnswers.toSet() ?? const <String>{};

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in options) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (correctSet.contains(option))
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade600)
                else
                  Icon(defaultIcon, size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: correctSet.contains(option)
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontWeight: correctSet.contains(option)
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _ScaleDetail extends StatelessWidget {
  final AiQuestion question;

  const _ScaleDetail({required this.question});

  @override
  Widget build(BuildContext context) {
    final min = question.scaleMin ?? 1;
    final max = question.scaleMax ?? 5;
    final minLabel = question.scaleMinLabel;
    final maxLabel = question.scaleMaxLabel;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          if (minLabel != null) ...[
            Text(
              minLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            '$min',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.purple,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              height: 2,
              color: AppColors.purple.withValues(alpha: 0.2),
            ),
          ),
          Text(
            '$max',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.purple,
              fontSize: 13,
            ),
          ),
          if (maxLabel != null) ...[
            const SizedBox(width: 6),
            Text(
              maxLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingDetail extends StatelessWidget {
  final AiQuestion question;

  const _RatingDetail({required this.question});

  @override
  Widget build(BuildContext context) {
    final scale = question.ratingScale ?? 5;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          for (var i = 0; i < scale; i++) ...[
            const Icon(Icons.star_border, size: 20, color: AppColors.purple),
            if (i < scale - 1) const SizedBox(width: 2),
          ],
          const SizedBox(width: 8),
          Text(
            '$scale stars',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Quiz: correct answer for text questions ──────────────────────────────────

class _CorrectAnswerDetail extends StatelessWidget {
  final AiQuestion question;
  const _CorrectAnswerDetail({required this.question});

  @override
  Widget build(BuildContext context) {
    final answers = question.grading?.correctAnswers ?? const [];
    if (answers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              answers.length == 1
                  ? 'Correct answer: ${answers.first}'
                  : 'Correct answers: ${answers.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Form bar ───────────────────────────────────────────────────────────

class _CreateFormBar extends StatelessWidget {
  final bool isCreating;
  final bool isQuiz;
  final VoidCallback onTap;

  const _CreateFormBar({
    required this.isCreating,
    required this.isQuiz,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: isCreating ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purple,
            disabledBackgroundColor: AppColors.purple.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: isCreating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isQuiz ? 'Create Quiz' : 'Create Form',
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}
