import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_bone.dart';

class EditorSkeleton extends StatelessWidget {
  const EditorSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.groupedBackground,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _SkeletonHeaderCard(),
          SizedBox(height: 8),
          _SkeletonQuestionCard(),
          _SkeletonQuestionCard(),
          _SkeletonQuestionCard(),
        ],
      ),
    );
  }
}

class _SkeletonHeaderCard extends StatelessWidget {
  const _SkeletonHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBone(width: 200, height: 20, radius: 4),
            SizedBox(height: 10),
            SkeletonBone(width: double.infinity, height: 13, radius: 4),
          ],
        ),
      ),
    );
  }
}

class _SkeletonQuestionCard extends StatelessWidget {
  const _SkeletonQuestionCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBone(width: 180, height: 14, radius: 4),
            SizedBox(height: 10),
            SkeletonBone(width: 72, height: 22, radius: 12),
            SizedBox(height: 12),
            SkeletonBone(width: double.infinity, height: 11, radius: 4),
            SizedBox(height: 6),
            SkeletonBone(width: 160, height: 11, radius: 4),
          ],
        ),
      ),
    );
  }
}
