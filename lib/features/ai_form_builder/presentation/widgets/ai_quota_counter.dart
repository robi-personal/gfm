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
    final isPremium   = status.isPremium;

    final label = isUnlimited
        ? 'Unlimited generations'
        : isExhausted
            ? 'No generations left'
            : '$balance generation${balance == 1 ? '' : 's'} remaining';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.purpleMid, AppColors.purple600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isUnlimited) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Resets monthly',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onUpgradeTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        color: AppColors.purple600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isUnlimited) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (balance / 10.0).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isExhausted
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
