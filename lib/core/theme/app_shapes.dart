import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShapes {
  // ── Border radii ──────────────────────────────────────────────────────────
  static const cardRadius   = BorderRadius.all(Radius.circular(14));
  static const cardRadius2  = BorderRadius.all(Radius.circular(16));
  static const pillRadius   = BorderRadius.all(Radius.circular(999));
  static const buttonRadius = BorderRadius.all(Radius.circular(14));
  static const fabRadius    = BorderRadius.all(Radius.circular(30)); // 60 px circle

  // 28 px top corners for bottom sheets
  static const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

  // ── Shadows ───────────────────────────────────────────────────────────────

  // rgba(20,16,40, 0.03)
  static const cardShadow = [
    BoxShadow(
      color: Color(0x08141028),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  // rgba(123,44,224, 0.35)
  static const primaryButtonShadow = [
    BoxShadow(
      color: Color(0x597B2CE0),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];

  // rgba(123,44,224, 0.45)
  static const fabShadow = [
    BoxShadow(
      color: Color(0x737B2CE0),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  // ── Gradients ─────────────────────────────────────────────────────────────

  // #8B4FEE → #6920C4  (purple500 → purple700)
  static const primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8B4FEE), Color(0xFF6920C4)],
  );

  // ── Common decorations ────────────────────────────────────────────────────

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: cardRadius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: cardShadow,
      );

  static BoxDecoration get cardDecoration2 => BoxDecoration(
        color: AppColors.surface,
        borderRadius: cardRadius2,
        border: Border.all(color: AppColors.hairline),
        boxShadow: cardShadow,
      );

  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: buttonRadius,
        boxShadow: primaryButtonShadow,
      );

  static BoxDecoration get fabDecoration => BoxDecoration(
        gradient: primaryGradient,
        shape: BoxShape.circle,
        boxShadow: fabShadow,
      );
}
