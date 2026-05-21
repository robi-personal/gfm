import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';
import '../theme/app_text_styles.dart';

/// Full-width primary button — gradient fill, 54 px tall, purple shadow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 54,
          decoration: AppShapes.primaryButtonDecoration,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Outlined / ghost secondary button — white bg, hairline border.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppShapes.buttonRadius,
            border: Border.all(color: AppColors.hairline),
            boxShadow: AppShapes.cardShadow,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              ?leading,
              Text(
                label,
                style: AppTextStyles.cardTitle.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text-only tertiary button — no background, purple label.
class TertiaryTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const TertiaryTextButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.purple600,
          ),
        ),
      ),
    );
  }
}

/// Tappable icon button with an optional label below.
class DsIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final Color? color;
  final double iconSize;

  const DsIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.label,
    this.color,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.purple600;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: label == null
            ? Icon(icon, size: iconSize, color: fg)
            : Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Icon(icon, size: iconSize, color: fg),
                  Text(
                    label!,
                    style: AppTextStyles.meta.copyWith(color: fg),
                  ),
                ],
              ),
      ),
    );
  }
}
