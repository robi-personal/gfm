import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

enum FormThumbVariant { regular, imported }

/// ClipboardThumb with an optional provenance badge overlay.
/// - [regular]  — plain clipboard (owned forms)
/// - [imported] — clipboard + blue disc with down-arrow (isOwned: false)
class FormClipboardThumb extends StatelessWidget {
  final FormThumbVariant variant;
  final double size;

  const FormClipboardThumb({
    super.key,
    this.variant = FormThumbVariant.regular,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipboardThumb(size: size),
        if (variant == FormThumbVariant.imported)
          Positioned(
            bottom: -2,
            right: -2,
            child: _ProvBadge(
              color: const Color(0xFF1A56DB),
              child: const Icon(Icons.arrow_downward_rounded,
                  size: 8, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _ProvBadge extends StatelessWidget {
  final Color color;
  final Widget child;

  const _ProvBadge({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
