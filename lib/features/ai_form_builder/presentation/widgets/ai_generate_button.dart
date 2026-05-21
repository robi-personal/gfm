import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

class AiGenerateButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const AiGenerateButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: (enabled || isLoading) ? AppColors.purple600 : AppColors.iconInactive,
          borderRadius: BorderRadius.circular(14),
          boxShadow: (enabled || isLoading)
              ? [
                  BoxShadow(
                    color: AppColors.purple600.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const CupertinoActivityIndicator(color: Colors.white, radius: 11)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: enabled ? Colors.white : AppColors.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generate',
                      style: TextStyle(
                        color: enabled ? Colors.white : AppColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
