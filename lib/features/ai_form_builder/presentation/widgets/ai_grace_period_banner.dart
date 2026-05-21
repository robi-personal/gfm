import 'package:flutter/cupertino.dart';

import '../../../../../core/design.dart';

class AiGracePeriodBanner extends StatelessWidget {
  final DateTime until;

  const AiGracePeriodBanner({super.key, required this.until});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Billing issue — service active until ${_formatDate(until)}',
              style: const TextStyle(
                color: Color(0xFF7D4E00),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}
