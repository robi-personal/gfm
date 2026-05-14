import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand purple
  static const purple = Color(0xFF772FC0);
  static const purpleDark = Color(0xFF3B1278);
  static const purpleMid = Color(0xFF5418A0);
  static const purpleAccent = Color(0xFF9B4FE8);
  static const purpleTint = Color(0xFFF3EBFC);
  static const purpleTintDeep = Color(0xFFF3F0FA);

  // Text
  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary = Color(0xFFC7C7CC);
  static const textDark = Color(0xFF3C3C43);

  // Backgrounds
  static const background = Colors.white;
  static const groupedBackground = Color(0xFFF2F2F7);
  static const signInBackground = Color(0xFFF7F6FB);

  // Borders / separators
  static const separator = Color(0xFFE8E8E8);
  static const separatorLight = Color(0xFFF2F2F7);
  static const borderSubtle = Color(0xFFEEEEEE);

  // Skeleton / shimmer
  static const shimmerBase = Color(0xFFE5E5EA);
  static const shimmerHighlight = Color(0xFFF2F2F7);

  // Inactive / placeholder icons
  static const iconInactive = Color(0xFFD1D1D6);

  // Semantic
  static const success = Color(0xFF34A853);
  static const error = Color(0xFFFF3B30);
  static const warning = Color(0xFFFF9500);
}
