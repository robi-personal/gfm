import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Design system tokens ──────────────────────────────────────────────────
  static const purple50  = Color(0xFFF6F1FE);
  static const purple100 = Color(0xFFEFE4FE);
  static const purple200 = Color(0xFFDFC9FD);
  static const purple300 = Color(0xFFC7A4FB);
  static const purple400 = Color(0xFFA876F7);
  static const purple500 = Color(0xFF8B4FEE);
  static const purple600 = Color(0xFF7B2CE0); // primary
  static const purple700 = Color(0xFF6920C4);
  static const purple800 = Color(0xFF561A9F);

  static const bg       = Color(0xFFF5F4F8); // app background
  static const surface  = Color(0xFFFFFFFF); // card background
  static const ink      = Color(0xFF1A1626); // primary text
  static const ink2     = Color(0xFF3D3850); // body text
  static const muted    = Color(0xFF7F7A92); // secondary text
  static const muted2   = Color(0xFFB0ABBE); // placeholder text
  static const hairline = Color(0xFFECEAF1); // 1 px borders / dividers

  // ── Legacy aliases — keep to avoid breaking existing screens ─────────────
  static const purple         = purple600;
  static const purpleDark     = purple800;
  static const purpleMid      = purple700;
  static const purpleAccent   = purple500;
  static const purpleTint     = purple50;
  static const purpleTintDeep = purple100;

  static const textPrimary   = ink;
  static const textSecondary = muted;
  static const textTertiary  = muted2;
  static const textDark      = ink2;

  static const background        = surface;
  static const groupedBackground = bg;
  static const signInBackground  = bg;

  static const separator      = hairline;
  static const separatorLight = Color(0xFFF2F2F7);
  static const borderSubtle   = hairline;

  static const shimmerBase      = Color(0xFFE5E5EA);
  static const shimmerHighlight = Color(0xFFF2F2F7);
  static const iconInactive     = Color(0xFFD1D1D6);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const success = Color(0xFF34A853);
  static const error   = Color(0xFFD0302A);
  static const warning = Color(0xFFFF9500);
}
