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
    final isPaid = isPremium;

    final gradientColors = isPaid
        ? const [Color(0xFF7B2CE0), Color(0xFFD4A017)]
        : const [Color(0xFF7B2CE0), Color(0xFF5614B0)];
    final shadowColor = isPaid
        ? const Color(0xFFAA6BE0)
        : const Color(0xFF7B2CE0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid ? Icons.workspace_premium_rounded : Icons.auto_awesome,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // Quota text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnlimited
                          ? 'Unlimited'
                          : isExhausted
                              ? 'No generations left'
                              : '$balance left',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUnlimited ? 'All features unlocked' : _resetLabel(status.subscriptionProductId),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons
              Row(
                children: [
                  _IconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
                  if (!isPremium) ...[
                    const SizedBox(width: 8),
                    _UpgradeChip(onTap: onUpgradeTap),
                  ],
                ],
              ),
            ],
          ),
          if (_planBadge(status.subscriptionProductId) != null) ...[
            const SizedBox(height: 12),
            _planBadge(status.subscriptionProductId)!,
          ],
        ],
      ),
    );
  }

  static String _resetLabel(String? productId) {
    if (productId == null) return 'Free · resets monthly';
    final id = productId.toLowerCase();
    if (id.contains('weekly'))  return 'Resets weekly';
    if (id.contains('yearly'))  return 'Resets yearly';
    return 'Resets monthly';
  }

  static Widget? _planBadge(String? productId) {
    if (productId == null) return null;
    final id = productId.toLowerCase();
    final (label, color, icon) = id.contains('weekly')
        ? ('WEEKLY',  const Color(0xFF34D399), Icons.bolt_rounded)
        : id.contains('yearly')
            ? ('YEARLY',  const Color(0xFFFBBF24), Icons.workspace_premium_rounded)
            : id.contains('monthly')
                ? ('MONTHLY', const Color(0xFF60A5FA), Icons.calendar_month_rounded)
                : (null, null, null);
    if (label == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

class _UpgradeChip extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/dashboard_premium.svg', width: 13, height: 13),
            const SizedBox(width: 4),
            const Text(
              'Upgrade',
              style: TextStyle(
                color: AppColors.purple600,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
