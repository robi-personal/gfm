import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The single error modal widget for this app — see spec §8.1.
///
/// Rules:
/// - Tapping the scrim does NOT dismiss it; only explicit button taps do.
/// - Never show raw HTTP codes or exception strings via this widget.
/// - [primaryLabel] is the recovery action (right). [secondaryLabel] is the
///   destructive / give-up action (left). Never use "OK" for a destructive
///   action; use concrete verbs ("Discard", "Delete", "Cancel").
/// - All error modals in the app MUST go through [ErrorModal.show]. No
///   ad-hoc `showDialog` calls with error content anywhere else.
class ErrorModal extends StatelessWidget {
  final String title;
  final String body;

  /// Primary (recovery) button — right side. Required.
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Optional secondary (destructive / give-up) button — left side.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ErrorModal({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Shows the modal. Returns when the user has dismissed it via a button.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => ErrorModal(
        title: title,
        body: body,
        primaryLabel: primaryLabel,
        onPrimary: onPrimary,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Body ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Actions ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    if (secondaryLabel != null) ...[
                      Expanded(
                        child: _SecondaryButton(
                          label: secondaryLabel!,
                          onTap: () {
                            Navigator.of(context).pop();
                            onSecondary?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _PrimaryButton(
                        label: primaryLabel,
                        onTap: () {
                          Navigator.of(context).pop();
                          onPrimary();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.purple,
      pressedOpacity: 0.8,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      minimumSize: Size.zero,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.groupedBackground,
      pressedOpacity: 0.7,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
