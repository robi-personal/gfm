import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

enum PlanType { weekly, monthly, yearly }

class PremiumBanner extends StatefulWidget {
  final int generationsLeft;
  final PlanType currentPlan;
  final Future<void> Function() onRefresh;
  final bool showFooter;
  final bool showAnimations;
  final bool showBorderShimmer;
  final bool showRefreshButton;
  final BorderRadius? borderRadius;
  final String? userName;
  final String? userEmail;
  final String? userPhotoUrl;
  final double topPadding;

  const PremiumBanner({
    super.key,
    required this.generationsLeft,
    required this.currentPlan,
    required this.onRefresh,
    this.showFooter = true,
    this.showAnimations = true,
    this.showBorderShimmer = true,
    this.showRefreshButton = true,
    this.borderRadius,
    this.userName,
    this.userEmail,
    this.userPhotoUrl,
    this.topPadding = 0,
  });

  @override
  State<PremiumBanner> createState() => _PremiumBannerState();
}

class _PremiumBannerState extends State<PremiumBanner>
    with TickerProviderStateMixin {
  late final AnimationController _sparkleController;
  late final AnimationController _shimmerController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await widget.onRefresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  String get _planLabel => switch (widget.currentPlan) {
    PlanType.weekly => 'Weekly',
    PlanType.monthly => 'Monthly',
    PlanType.yearly => 'Yearly',
  };

  IconData get _planIcon => switch (widget.currentPlan) {
    PlanType.weekly => Icons.bolt_rounded,
    PlanType.monthly => Icons.calendar_month_rounded,
    PlanType.yearly => Icons.workspace_premium_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(18),
      child: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFF7B2CE0)),
            ),
          ),
          // Dot grid
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _DotGridPainter()))),
          // Purple glow top-left
          Positioned(
            left: -30,
            top: -50,
            child: IgnorePointer(child: _GlowCircle(radius: 180, color: const Color(0x388B5CF6))),
          ),
          // Gold glow bottom-right
          Positioned(
            right: -40,
            bottom: -60,
            child: IgnorePointer(child: _GlowCircle(radius: 200, color: const Color(0x30F5B428))),
          ),
          if (widget.showAnimations) ...[
            // Border shimmer — sweeps around the full perimeter
            if (widget.showBorderShimmer)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, _) => CustomPaint(
                      painter: _BorderShimmerPainter(_shimmerController.value),
                    ),
                  ),
                ),
              ),
            // Sparkles
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _sparkleController,
                    builder: (context, _) => CustomPaint(
                      painter: _SparklePainter(_sparkleController.value),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Content with padding
          Padding(
            padding: EdgeInsets.fromLTRB(18, 14 + widget.topPadding, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1 — top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PremiumBadge(),
                    if (widget.showRefreshButton)
                      _RefreshButton(onPressed: _handleRefresh, isLoading: _isRefreshing),
                  ],
                ),
                if (widget.userName != null || widget.userEmail != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    spacing: 10,
                    children: [
                      _UserAvatar(
                        photoUrl: widget.userPhotoUrl,
                        displayName: widget.userName,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.userName != null)
                              Text(
                                widget.userName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (widget.userEmail != null)
                              Text(
                                widget.userEmail!,
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
                const SizedBox(height: 16),
                // Row 2 — generation count
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'You have ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: NumberFormat(
                          '#,###',
                        ).format(widget.generationsLeft),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                       TextSpan(
                        text: ' AI Form Generations Left',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showFooter) ...[
                  const SizedBox(height: 4),
                  const Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: Color(0x1AFFFFFF),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Current plan',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      _PlanPill(icon: _planIcon, label: _planLabel),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE68A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A017).withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/dashboard_premium.svg',
            width: 12,
            height: 12,
            colorFilter: const ColorFilter.mode(
              Color(0xFF7D4E00),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'PREMIUM',
            style: TextStyle(
              color: Color(0xFF7D4E00),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _RefreshButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: isLoading
            ? const CupertinoActivityIndicator(color: Colors.white, radius: 8)
            : const Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlanPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
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

class _GlowCircle extends StatelessWidget {
  final double radius;
  final Color color;

  const _GlowCircle({required this.radius, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const spacing = 18.0;
    const radius = 1.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}

class _BorderShimmerPainter extends CustomPainter {
  final double progress;

  _BorderShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final angle = progress * 2 * math.pi;

    // Wide soft glow pass
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: const [
            Colors.transparent,
            Color(0x00F5B932),
            Color(0x88F5B932),
            Color(0x00F5B932),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
          transform: GradientRotation(angle),
        ).createShader(rect)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke,
    );

    // Bright core pass
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: const [
            Colors.transparent,
            Color(0x00F5B932),
            Color(0xFFF5B932),
            Color(0x00F5B932),
            Colors.transparent,
          ],
          stops: const [0.0, 0.44, 0.5, 0.56, 1.0],
          transform: GradientRotation(angle),
        ).createShader(rect)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_BorderShimmerPainter old) => old.progress != progress;
}

class _SparklePainter extends CustomPainter {
  final double t;

  _SparklePainter(this.t);

  static const _sparkles = [
    // (xFraction, yFraction, size, isGold, phaseOffset, rotateSpeed)
    (0.85, 0.12, 5.0, true, 0.0, 0.3),
    (0.96, 0.45, 3.0, true, 0.3, 0.0),
    (0.08, 0.15, 3.0, false, 0.6, 0.0),
    (0.92, 0.80, 2.5, true, 0.1, 0.0),
    (0.04, 0.55, 2.5, false, 0.8, 0.0),
    (0.12, 0.85, 3.5, true, 0.45, 0.2),
    // dots
    (0.55, 0.08, 1.5, false, 0.2, 0.0),
    (0.72, 0.45, 1.2, true, 0.5, 0.0),
    (0.38, 0.92, 1.2, false, 0.7, 0.0),
    (0.88, 0.25, 1.0, true, 0.15, 0.0),
  ];

  void _drawStar(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double opacity,
    double angle,
  ) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final outerAngle = angle + i * math.pi / 2;
      final innerAngle = outerAngle + math.pi / 4;
      final outer = Offset(
        center.dx + math.cos(outerAngle) * size,
        center.dy + math.sin(outerAngle) * size,
      );
      final inner = Offset(
        center.dx + math.cos(innerAngle) * size * 0.35,
        center.dy + math.sin(innerAngle) * size * 0.35,
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const goldColor = Color(0xFFF5C842);
    const purpleColor = Color(0xFFB07EF8);

    for (final s in _sparkles) {
      final (xF, yF, sz, isGold, phase, rotSpeed) = s;
      final isDot = sz <= 2.5;

      final rawT = ((t + phase) % 1.0);
      final pulse = (math.sin(rawT * math.pi * 2) + 1) / 2;
      final opacity = isDot ? 0.12 + pulse * 0.18 : 0.25 + pulse * 0.55;
      final angle = rotSpeed > 0 ? t * math.pi * 2 * rotSpeed : 0.0;

      final center = Offset(xF * size.width, yF * size.height);
      final color = isGold ? goldColor : purpleColor;

      if (isDot) {
        canvas.drawCircle(
          center,
          sz,
          Paint()..color = color.withValues(alpha: opacity),
        );
      } else {
        _drawStar(canvas, center, sz, color, opacity, angle);
      }
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}
