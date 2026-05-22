import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

class QuestionsEmptyState extends StatelessWidget {
  const QuestionsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.question_circle,
                size: 56,
                color: AppColors.iconInactive,
              ),
              const SizedBox(height: 16),
              Text(
                'No questions yet.',
                style: AppTextStyles.cardTitle.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap + below to add your first question.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
