import 'package:flutter/cupertino.dart';

import '../../../../../core/design.dart';

class AiFilePickerButton extends StatelessWidget {
  final String? fileName;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const AiFilePickerButton({
    super.key,
    required this.fileName,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (fileName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.purple50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.doc_text_fill, color: AppColors.purple600, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.purple600,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            GestureDetector(
              onTap: enabled ? onClear : null,
              child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.purple600, size: 20),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: enabled ? onPick : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.iconInactive,
            style: BorderStyle.solid,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.arrow_up_doc, color: AppColors.purple600, size: 20),
            SizedBox(width: 8),
            Text(
              'Choose PDF',
              style: TextStyle(
                color: AppColors.purple600,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
