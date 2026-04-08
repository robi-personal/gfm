import 'package:flutter/material.dart';

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
      barrierDismissible: false, // tapping scrim does not dismiss
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
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: Text(body, style: theme.textTheme.bodyMedium),
      actions: [
        if (secondaryLabel != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSecondary?.call();
            },
            child: Text(secondaryLabel!),
          ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onPrimary();
          },
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}
