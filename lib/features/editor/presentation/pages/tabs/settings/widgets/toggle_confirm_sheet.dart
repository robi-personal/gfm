import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/ds_buttons.dart';

Future<bool?> showToggleConfirmSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required String body,
  required String continueLabel,
  String cancelLabel = 'Later',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
    builder: (_) => _ToggleConfirmSheet(
      icon: icon,
      title: title,
      subtitle: subtitle,
      body: body,
      continueLabel: continueLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _ToggleConfirmSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final String continueLabel;
  final String cancelLabel;

  const _ToggleConfirmSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.continueLabel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 28;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29141028),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E1EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            spacing: 14,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.purple50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.purple600, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: continueLabel,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text(
                  cancelLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
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
