import 'package:flutter/material.dart';

import '../../../../../core/design.dart';
import '../../domain/entities/user_status.dart';

class AiQuotaCounter extends StatelessWidget {
  final UserStatus status;
  final VoidCallback onUpgradeTap;

  const AiQuotaCounter({
    super.key,
    required this.status,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlimited = status.unlimited;
    final balance     = status.quotaBalance;
    final isExhausted = status.isQuotaExhausted;

    final counterText = isUnlimited
        ? 'Unlimited generations'
        : '$balance generations remaining';

    final barColor = isExhausted
        ? AppColors.error
        : isUnlimited || balance > 5
            ? AppColors.purple600
            : AppColors.warning;

    final fraction = isUnlimited ? 1.0 : (balance / 10.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: (!isUnlimited && isExhausted) ? onUpgradeTap : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShapes.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.purple600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    counterText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isExhausted ? AppColors.error : AppColors.ink,
                    ),
                  ),
                ),
                if (!isUnlimited && !status.isPremium)
                  const Icon(Icons.chevron_right, color: AppColors.muted2, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: AppColors.bg,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
