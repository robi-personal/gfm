import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

Future<bool?> showImportInfoDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
    builder: (ctx) => const _ImportInfoSheet(),
  );
}

class _ImportInfoSheet extends StatelessWidget {
  const _ImportInfoSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 28;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29141028),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E1EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          // Header row
          Row(
            spacing: 14,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.purple50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.info_circle,
                    color: AppColors.purple600, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heads up',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    'Privacy & scope',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Body copy
          const Text(
            'For your privacy, GFM only sees forms it created here. '
            'Forms you made on the Google Forms website or in other apps '
            'won\'t show up automatically — tap below to browse your Drive '
            'and pick the ones to import.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 16),
          // Privacy bullets card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.purple50,
              border: Border.all(color: AppColors.purple100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              spacing: 10,
              children: const [
                _BulletRow(text: 'Only see forms you select'),
                _BulletRow(text: 'Revoke access anytime in Settings'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Primary action
          PrimaryButton(
            label: 'Import Existing Forms',
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 4),
          // Tertiary action
          SizedBox(
            width: double.infinity,
            height: 44,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: const Center(
                child: Text(
                  'Maybe later',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;

  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.purple600,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 9, color: Colors.white),
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.purple600,
          ),
        ),
      ],
    );
  }
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
                if (name.isNotEmpty) Navigator.of(context).pop(name);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(null),
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
