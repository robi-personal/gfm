import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

/// In-sheet confirmation panel shown when the user picks "File upload" in the
/// type picker. Lets them confirm or back out without losing their question state.
class QuestionFileUploadPrompt extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  const QuestionFileUploadPrompt({
    super.key,
    required this.onCancel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.purple,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add file upload via Google Forms',
            textAlign: TextAlign.center,
            style: AppTextStyles.screenHeader,
          ),
          const SizedBox(height: 10),
          Text(
            'For your privacy, this app uses minimal Google permissions — '
            'and Google only allows file upload questions to be added '
            'through the Google Forms website. Continue to open this form '
            'there. When you come back, your new question will appear '
            'automatically.',
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(
              fontWeight: FontWeight.normal,
              height: 1.45,
              color: const Color(0xFF6E6E73),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.purple,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Continue',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.separator),
              ),
              child: Center(
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
