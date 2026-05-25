import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../../core/design.dart';
import '../../domain/entities/user_status.dart';

class AiQuotaCounter extends StatelessWidget {
  final UserStatus status;
  final VoidCallback onUpgradeTap;
  final String? userName;
  final String? userEmail;
  final String? userPhotoUrl;
  final double topPadding;

  const AiQuotaCounter({
    super.key,
    required this.status,
    required this.onUpgradeTap,
    this.userName,
    this.userEmail,
    this.userPhotoUrl,
    this.topPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(color: const Color(0xFF7B2CE0)),
          ),
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _DotGridPainter())),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 14 + topPadding, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _FreeLabel(),
                if (userName != null || userEmail != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    spacing: 10,
                    children: [
                      _UserAvatar(photoUrl: userPhotoUrl, displayName: userName),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (userName != null)
                              Text(
                                userName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (userEmail != null)
                              Text(
                                userEmail!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: NumberFormat('#,###').format(status.quotaBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: '  AI Form Generations Left',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _UpgradeButton(onTap: onUpgradeTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;

  const _UserAvatar({this.photoUrl, this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial =
        (displayName?.isNotEmpty == true ? displayName![0] : null) ?? '?';

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white.withValues(alpha: 0.20),
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (e, _) {},
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.white.withValues(alpha: 0.20),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FreeLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.5),
      ),
      child: const Text(
        'FREE TIER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/dashboard_premium.svg',
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(AppColors.purple600, BlendMode.srcIn),
            ),
            const SizedBox(width: 5),
            const Text(
              'Upgrade',
              style: TextStyle(
                color: AppColors.purple600,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const spacing = 18.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}
