import 'package:flutter/material.dart';

/// A single opaque bone used inside a [Shimmer] widget.
/// The shimmer effect is applied by the ancestor [Shimmer.fromColors] —
/// this widget just provides the shape.
class SkeletonBone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBone({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
