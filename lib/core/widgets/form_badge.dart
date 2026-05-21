import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_text_styles.dart';

enum FormBadgeVariant { ai, quiz, imported }

/// Small uppercase badge. Three variants:
/// - [FormBadgeVariant.ai]       — purple50 bg / purple700 text + sparkle icon
/// - [FormBadgeVariant.quiz]     — amber tint bg / warm-brown text
/// - [FormBadgeVariant.imported] — blue tint bg / blue text
class FormBadge extends StatelessWidget {
  final FormBadgeVariant variant;

  const FormBadge(this.variant, {super.key});

  const FormBadge.ai({super.key}) : variant = FormBadgeVariant.ai;
  const FormBadge.quiz({super.key}) : variant = FormBadgeVariant.quiz;
  const FormBadge.imported({super.key}) : variant = FormBadgeVariant.imported;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (variant) {
      FormBadgeVariant.ai       => (AppColors.purple50, AppColors.purple700, 'AI',       Icons.auto_awesome),
      FormBadgeVariant.quiz     => (const Color(0xFFFEF3E2), const Color(0xFFB85C00), 'QUIZ',     null),
      FormBadgeVariant.imported => (const Color(0xFFE8F0FE), const Color(0xFF1A56DB), 'IMPORTED', null),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppShapes.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          if (icon != null)
            Icon(icon, size: 10, color: fg),
          Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(color: fg, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
