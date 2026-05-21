import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';

/// 26–28 px rounded square in purple600 with a clipboard glyph.
/// Used in the nav bar and sign-in screen.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.purple600,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: AppShapes.primaryButtonShadow,
      ),
      child: Center(
        child: Icon(
          Icons.assignment_outlined,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}
