import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

Future<bool?> showFileUploadInfoDialog(
  BuildContext context, {
  required bool isEditing,
}) {
  final title = isEditing ? 'Edit file upload' : 'Add file upload';
  final body = isEditing
      ? 'For your privacy, this app uses minimal Google permissions — and '
          'Google only allows file upload questions to be edited through '
          'the Google Forms website. Tap below to open this form there. '
          'When you come back, your changes will appear automatically.'
      : 'For your privacy, this app uses minimal Google permissions — and '
          'Google only allows file upload questions to be added through '
          'the Google Forms website. Tap below to open this form there. '
          'When you come back, your new question will appear automatically.';

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_up_doc,
                    color: AppColors.purple,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: AppColors.groupedBackground),
            const SizedBox(height: 12),
            Text(
              body,
              style: AppTextStyles.meta.copyWith(height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
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
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.groupedBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15, color: AppColors.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
