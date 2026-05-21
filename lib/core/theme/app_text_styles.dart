import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  // 26 / 700 / -0.6
  static const title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  // 18 / 700 / -0.3  (midpoint of 17–20 range)
  static const screenHeader = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  // 16 / 600 / -0.2
  static const cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  // 14 / 1.55 line-height
  static const body = TextStyle(
    fontSize: 14,
    height: 1.55,
    color: AppColors.ink2,
  );

  // 14.5 / 1.55
  static const bodyLarge = TextStyle(
    fontSize: 14.5,
    height: 1.55,
    color: AppColors.ink2,
  );

  // 12 / 500
  static const meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  // 11 / 700 / 0.8  — uppercase section labels
  static const sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.muted,
  );
}
