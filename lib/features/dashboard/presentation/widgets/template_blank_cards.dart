import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design.dart';
import '../../../../core/widgets/error_modal.dart';
import '../cubit/dashboard_cubit.dart';
import '../pages/template_data.dart';
import 'dashboard_dialogs.dart';

// ── Blank cards row ───────────────────────────────────────────────────────────

class TemplateBlankCardsRow extends StatelessWidget {
  const TemplateBlankCardsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BlankCard(
            icon: CupertinoIcons.add,
            title: 'Blank Form',
            onCreate: (ctx) => _create(ctx, quiz: false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BlankCard(
            icon: CupertinoIcons.question,
            title: 'Blank Quiz',
            onCreate: (ctx) => _create(ctx, quiz: true),
          ),
        ),
      ],
    );
  }

  void _create(BuildContext context, {required bool quiz}) async {
    final defaultName = quiz ? 'Untitled quiz' : 'Untitled form';
    final name = await showFormNameSheet(
      context,
      prefill: defaultName,
      isQuiz: quiz,
    );
    if (name == null || !context.mounted) return;

    final cubit = context.read<DashboardCubit>();
    try {
      if (quiz) {
        await cubit.createForm(
          title: name,
          items: kBlankQuizTemplate.items,
          enableQuiz: true,
        );
      } else {
        await cubit.createForm(title: name);
      }
    } catch (_) {
      if (!context.mounted) return;
      ErrorModal.show(
        context,
        title: "Couldn't create form.",
        body: 'Check your connection and try again.',
        secondaryLabel: 'Cancel',
        onSecondary: () {},
        primaryLabel: 'Retry',
        onPrimary: () => _create(context, quiz: quiz),
      );
    }
  }
}

// ── Blank card ────────────────────────────────────────────────────────────────

class _BlankCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final void Function(BuildContext) onCreate;

  const _BlankCard({
    required this.icon,
    required this.title,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppShapes.cardRadius2,
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShapes.cardShadow,
      ),
      child: InkWell(
        onTap: () => onCreate(context),
        borderRadius: AppShapes.cardRadius2,
        splashColor: AppColors.purple600.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.purple600.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.purple600, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
