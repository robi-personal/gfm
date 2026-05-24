import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/design.dart';
import '../../domain/entities/user_status.dart';

class AiQuotaCounter extends StatelessWidget {
  final UserStatus status;
  final VoidCallback onUpgradeTap;
  final VoidCallback onRefresh;

  const AiQuotaCounter({
    super.key,
    required this.status,
    required this.onUpgradeTap,
    required this.onRefresh,
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

    final resetLabel = _resetLabel(status.subscriptionProductId);
    final planBadge  = _planBadge(status.subscriptionProductId);

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (planBadge != null) ...[
                          const SizedBox(width: 8),
                          planBadge,
                        ],
                      ],
                    ),
                    if (!isUnlimited) ...[
                      const SizedBox(height: 2),
                      Text(
                        resetLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 16),
                ),
              ),
              if (!isPremium) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onUpgradeTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset('assets/dashboard_premium.svg', width: 14, height: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Upgrade',
                          style: TextStyle(
                            color: AppColors.purple600,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  static String _resetLabel(String? productId) {
    if (productId == null) return 'Resets monthly';
    if (productId.toLowerCase().contains('weekly')) return 'Resets weekly';
    if (productId.toLowerCase().contains('yearly')) return 'Resets yearly';
    return 'Resets monthly';
  }

  static Widget? _planBadge(String? productId) {
    if (productId == null) return null;
    final id = productId.toLowerCase();
    final (label, color) = id.contains('weekly')
        ? ('WEEKLY',  const Color(0xFF34D399))
        : id.contains('yearly')
            ? ('YEARLY',  const Color(0xFFFBBF24))
            : id.contains('monthly')
                ? ('MONTHLY', const Color(0xFF60A5FA))
                : (null, null);
    if (label == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
