import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 36–40 px clipboard illustration used as the leading icon on form rows.
/// Purple clip on top, purple50 body with faint line-rows inside.
class ClipboardThumb extends StatelessWidget {
  final double size;

  const ClipboardThumb({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ClipboardPainter()),
    );
  }
}

class _ClipboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()..color = AppColors.purple50;
    final clipPaint  = Paint()..color = AppColors.purple600;
    final linePaint  = Paint()
      ..color = AppColors.purple200
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final borderPaint = Paint()
      ..color = AppColors.purple200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.18, w * 0.84, h * 0.76),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, borderPaint);

    // Clip at top
    final clipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.3, h * 0.06, w * 0.4, h * 0.2),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(clipRect, clipPaint);

    // Line rows inside body
    final lineStartX = w * 0.22;
    final lineEndX   = w * 0.78;
    final lineY1 = h * 0.46;
    final lineY2 = h * 0.57;
    final lineY3 = h * 0.68;
    final lineY4 = h * 0.79;

    canvas.drawLine(Offset(lineStartX, lineY1), Offset(lineEndX, lineY1), linePaint);
    canvas.drawLine(Offset(lineStartX, lineY2), Offset(lineEndX, lineY2), linePaint);
    canvas.drawLine(Offset(lineStartX, lineY3), Offset(lineEndX * 0.85, lineY3), linePaint);
    canvas.drawLine(Offset(lineStartX, lineY4), Offset(lineEndX * 0.65, lineY4), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
