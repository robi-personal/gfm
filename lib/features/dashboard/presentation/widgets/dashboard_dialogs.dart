import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

Future<bool?> showImportInfoDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purple600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(CupertinoIcons.info,
                      color: AppColors.purple600, size: 15),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Heads up',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            const Text(
              "For your privacy, this app requests only minimal Google Drive "
              "access — so it can see only the forms it created here. Forms "
              "made on the Google Forms website or in other apps don't show "
              "up automatically. Tap below to browse your Drive and pick the "
              "ones to import.",
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.ink2),
            ),
            const SizedBox(height: 20),
            _DialogButton(
              label: 'Import Existing Forms',
              onTap: () => Navigator.of(ctx).pop(true),
              filled: true,
            ),
            const SizedBox(height: 10),
            _DialogButton(
              label: 'Later',
              onTap: () => Navigator.of(ctx).pop(false),
              filled: false,
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> showRenameDialog(BuildContext context,
    {required String current}) {
  final controller = TextEditingController(text: current)
    ..selection =
        TextSelection(baseOffset: 0, extentOffset: current.length);

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purple600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(CupertinoIcons.pencil,
                      color: AppColors.purple600, size: 15),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Rename Form',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
            const SizedBox(height: 12),
            const Text(
              'Enter a new name for your form.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style:
                  const TextStyle(fontSize: 15, color: AppColors.ink),
              cursorColor: AppColors.purple600,
              decoration: InputDecoration(
                hintText: 'Form name',
                hintStyle: const TextStyle(color: AppColors.muted2),
                filled: true,
                fillColor: AppColors.bg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.purple600, width: 1.5),
                ),
              ),
              onSubmitted: (v) {
                final name = v.trim();
                if (name.isNotEmpty) Navigator.of(ctx).pop(name);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(ctx).pop(null),
                    filled: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatefulBuilder(
                    builder: (ctx2, setLocal) {
                      controller.addListener(() => setLocal(() {}));
                      final canSave = controller.text.trim().isNotEmpty;
                      return _DialogButton(
                        label: 'Save',
                        onTap: canSave
                            ? () => Navigator.of(ctx)
                                .pop(controller.text.trim())
                            : null,
                        filled: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled
              ? (enabled
                  ? AppColors.purple600
                  : AppColors.purple600.withValues(alpha: 0.35))
              : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: filled && enabled
              ? [
                  BoxShadow(
                    color: AppColors.purple600.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
