import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../core/design.dart';
import '../../../../../core/widgets/skeleton_bone.dart';
import '../cubit/dashboard_cubit.dart';

// ── Empty state ───────────────────────────────────────────────────────────────

class DashboardEmptyState extends StatelessWidget {
  final VoidCallback? onAiBuilder;
  final VoidCallback? onCreateForm;
  final VoidCallback? onImport;

  const DashboardEmptyState({
    super.key,
    this.onAiBuilder,
    this.onCreateForm,
    this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/dashboard_no_form_banner.svg',
                  width: 160,
                ),
                const SizedBox(height: 26),
                const Text(
                  'Create your first form with AI',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenHeader,
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a form or quiz from a YouTube video, PDF, web page, or a photo of printed pages.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                // ── Primary CTA: AI generation ──────────────────────────────
                GestureDetector(
                  onTap: onAiBuilder,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.purple500, AppColors.purple700],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppShapes.primaryButtonShadow,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 9,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 18, color: Colors.white),
                        Text(
                          'Generate with AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Secondary actions ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _EmptyTextAction(
                      icon: Icons.edit_note_rounded,
                      label: 'Create manually',
                      onTap: onCreateForm,
                    ),
                    const SizedBox(width: 8),
                    Container(
                        width: 1, height: 14, color: AppColors.hairline),
                    const SizedBox(width: 8),
                    _EmptyTextAction(
                      icon: CupertinoIcons.link,
                      label: 'Import',
                      onTap: onImport,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.purple600.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.purple600.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Icon(CupertinoIcons.info_circle,
                          size: 15,
                          color: AppColors.purple600.withValues(alpha: 0.70)),
                      Expanded(
                        child: Text(
                          'Forms created on Google Forms web won\'t appear here automatically. Use Import Form to add them.',
                          style: AppTextStyles.meta
                              .copyWith(color: AppColors.purple600, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTextAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _EmptyTextAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.purple600),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.meta.copyWith(
                color: AppColors.purple600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSearchEmptyState extends StatelessWidget {
  final String query;

  const DashboardSearchEmptyState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.search, size: 48, color: AppColors.muted2),
            const SizedBox(height: 20),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen error ─────────────────────────────────────────────────────────

class DashboardFullScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const DashboardFullScreenError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wifi_slash,
                size: 48, color: AppColors.muted2),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.purple600,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShapes.primaryButtonShadow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Icon(CupertinoIcons.refresh,
                        size: 16, color: Colors.white),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline banners ────────────────────────────────────────────────────────────

class DashboardInlineBanner extends StatelessWidget {
  final String message;

  const DashboardInlineBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF9EC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        spacing: 8,
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              size: 15, color: AppColors.warning),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7D4E00), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardCacheBanner extends StatelessWidget {
  const DashboardCacheBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF4FF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        spacing: 8,
        children: [
          Icon(CupertinoIcons.cloud_download,
              size: 15, color: Color(0xFF0A84FF)),
          Text(
            'Showing cached list',
            style: TextStyle(color: Color(0xFF0A58CA), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.bg,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        itemCount: 6,
        itemBuilder: (_, i) => const _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppShapes.cardRadius2,
      ),
      child: const Row(
        children: [
          SkeletonBone(width: 40, height: 40, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBone(width: double.infinity, height: 13, radius: 4),
                SizedBox(height: 8),
                SkeletonBone(width: 100, height: 11, radius: 4),
              ],
            ),
          ),
          SizedBox(width: 14),
          SkeletonBone(width: 20, height: 20, radius: 4),
        ],
      ),
    );
  }
}

// ── Importing overlay ─────────────────────────────────────────────────────────

class DashboardImportingOverlay extends StatelessWidget {
  const DashboardImportingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 14,
              children: [
                CupertinoActivityIndicator(
                    radius: 12, color: AppColors.purple600),
                Text(
                  'Importing form…',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pull-to-refresh wrapper for empty state ───────────────────────────────────

class DashboardRefreshableEmptyState extends StatelessWidget {
  final String query;
  final VoidCallback? onAiBuilder;
  final VoidCallback? onCreateForm;
  final VoidCallback? onImport;

  const DashboardRefreshableEmptyState({
    super.key,
    required this.query,
    this.onAiBuilder,
    this.onCreateForm,
    this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.purple600,
      onRefresh: () => context.read<DashboardCubit>().refresh(),
      child: query.isNotEmpty
          ? DashboardSearchEmptyState(query: query)
          : DashboardEmptyState(
              onAiBuilder: onAiBuilder,
              onCreateForm: onCreateForm,
              onImport: onImport,
            ),
    );
  }
}
