import 'package:flutter/material.dart';

import '../../../../../core/design.dart';
import '../../domain/entities/form_entry.dart';

class DashboardSubHeader extends StatelessWidget {
  final int count;
  final String query;
  final SortOrder sortOrder;
  final VoidCallback onSort;

  const DashboardSubHeader({
    super.key,
    required this.count,
    required this.query,
    required this.sortOrder,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          _CountLabel(count: count),
          const Spacer(),
          _SortChip(sortOrder: sortOrder, onTap: onSort),
        ],
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  final int count;

  const _CountLabel({required this.count});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$count',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const TextSpan(
            text: ' forms',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final SortOrder sortOrder;
  final VoidCallback onTap;

  const _SortChip({required this.sortOrder, required this.onTap});

  String get _label => sortOrder == SortOrder.modifiedDesc
      ? 'Last modified'
      : 'Date created';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppShapes.pillRadius,
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShapes.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            const Icon(Icons.swap_vert_rounded,
                size: 14, color: AppColors.purple700),
            Text(
              _label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.purple700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
