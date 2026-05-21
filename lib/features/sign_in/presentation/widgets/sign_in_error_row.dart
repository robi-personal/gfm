import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

class SignInErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const SignInErrorRow({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 14, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.meta.copyWith(color: AppColors.error),
          ),
        ),
        GestureDetector(
          onTap: onRetry,
          child: Text(
            'Retry',
            style: AppTextStyles.meta.copyWith(
              color: AppColors.purple600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
