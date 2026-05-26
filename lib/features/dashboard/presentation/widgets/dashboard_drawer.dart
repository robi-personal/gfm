import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import '../../../../../core/design.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/widgets/simple_web_view_page.dart';
import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../../ai_form_builder/data/services/user_status_service.dart';
import '../../../ai_form_builder/presentation/widgets/ai_quota_counter.dart';
import '../../../ai_form_builder/presentation/widgets/premium_banner.dart';

const _kAppStoreId = '6479591930';
const _kAppStoreReviewUrl =
    'itms-apps://itunes.apple.com/app/id$_kAppStoreId?action=write-review';

class DashboardDrawer extends StatelessWidget {
  final VoidCallback onAiBuilder;
  final VoidCallback onCreateForm;
  final VoidCallback onImportForm;
  final VoidCallback onShowPaywall;
  final VoidCallback onRestorePurchases;

  const DashboardDrawer({
    super.key,
    required this.onAiBuilder,
    required this.onCreateForm,
    required this.onImportForm,
    required this.onShowPaywall,
    required this.onRestorePurchases,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bg,
      child: _DrawerContent(
        onAiBuilder: onAiBuilder,
        onCreateForm: onCreateForm,
        onImportForm: onImportForm,
        onShowPaywall: onShowPaywall,
        onRestorePurchases: onRestorePurchases,
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final VoidCallback onAiBuilder;
  final VoidCallback onCreateForm;
  final VoidCallback onImportForm;
  final VoidCallback onShowPaywall;
  final VoidCallback onRestorePurchases;

  const _DrawerContent({
    required this.onAiBuilder,
    required this.onCreateForm,
    required this.onImportForm,
    required this.onShowPaywall,
    required this.onRestorePurchases,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final service = getIt<UserStatusService>();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final status = service.status;

        final signInState = context.read<SignInCubit>().state;
        final String? displayName;
        final String? email;
        final String? photoUrl;
        if (signInState is Authenticated) {
          displayName = signInState.user.displayName;
          email = signInState.user.email.isNotEmpty ? signInState.user.email : null;
          photoUrl = signInState.user.photoUrl;
        } else {
          displayName = null;
          email = null;
          photoUrl = null;
        }

        // Membership banner — shown in-list above CREATE
        final Widget membershipBlock = status == null
            ? _DrawerBannerLoading()
            : status.isPremium
                ? PremiumBanner(
                    generationsLeft: status.quotaBalance,
                    currentPlan: _toPlanType(status.subscriptionProductId),
                    showAnimations: true,
                    showBorderShimmer: false,
                    showFooter: true,
                    showRefreshButton: false,
                    borderRadius: BorderRadius.circular(16),
                    topPadding: 0,
                    onRefresh: () => service.refresh(),
                  )
                : AiQuotaCounter(
                    status: status,
                    topPadding: 0,
                    userName: displayName,
                    userEmail: email,
                    userPhotoUrl: photoUrl,
                    onUpgradeTap: onShowPaywall,
                  );

        return Column(
          children: [
            // ── Simple user info header ──────────────────────────────
            _DrawerUserHeader(topPad: topPad, displayName: displayName, email: email, photoUrl: photoUrl),
            // ── Scrollable list ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
                children: [
                  membershipBlock,
                  const SizedBox(height: 16),
                  _buildSections(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSections(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DrawerSection(
          label: 'CREATE',
          items: [
            _DrawerItem(
              icon: Icons.auto_awesome_rounded,
              title: 'AI Form Builder',
              onTap: () {
                Navigator.of(context).pop();
                onAiBuilder();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.pencil,
              title: 'Create Form',
              onTap: () {
                Navigator.of(context).pop();
                onCreateForm();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.arrow_down_circle,
              title: 'Import Form',
              onTap: () {
                Navigator.of(context).pop();
                onImportForm();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DrawerSection(
          label: 'SUBSCRIPTION',
          items: [
            _DrawerItem(
              icon: CupertinoIcons.star_fill,
              title: 'Upgrade Plan',
              onTap: () {
                Navigator.of(context).pop();
                onShowPaywall();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.arrow_clockwise,
              title: 'Restore Purchases',
              onTap: () {
                Navigator.of(context).pop();
                onRestorePurchases();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DrawerSection(
          label: 'SUPPORT US',
          items: [
            _DrawerItem(
              icon: CupertinoIcons.hand_thumbsup,
              title: 'Rate the app',
              onTap: () {
                Navigator.of(context).pop();
                launchUrl(
                  Uri.parse(_kAppStoreReviewUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DrawerSection(
          label: 'LEGAL',
          items: [
            _DrawerItem(
              icon: CupertinoIcons.lock_shield,
              title: 'Privacy Policy',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SimpleWebViewPage(
                      title: 'Privacy Policy',
                      url: 'https://gfm.alphaiit.com/privacy.html',
                    ),
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.doc_text,
              title: 'Terms of Use',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SimpleWebViewPage(
                      title: 'Terms of Use',
                      url: 'https://gfm.alphaiit.com/terms.html',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DrawerSection(
          label: 'ACCOUNT',
          labelColor: AppColors.error,
          items: [
            _DrawerItem(
              icon: CupertinoIcons.square_arrow_right,
              title: 'Sign out',
              iconBg: AppColors.error,
              textColor: AppColors.error,
              onTap: () {
                Navigator.of(context).pop();
                context.read<SignInCubit>().signOut();
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Simple user info header ───────────────────────────────────────────────────

class _DrawerUserHeader extends StatelessWidget {
  final double topPad;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const _DrawerUserHeader({
    required this.topPad,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.purpleMid, AppColors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12,
        children: [
          _UserAvatar(photoUrl: photoUrl, displayName: displayName),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (displayName != null)
                  Text(
                    displayName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (email != null)
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Membership banner loading shimmer (in-list) ───────────────────────────────

class _DrawerBannerLoading extends StatefulWidget {
  const _DrawerBannerLoading();

  @override
  State<_DrawerBannerLoading> createState() => _DrawerBannerLoadingState();
}

class _DrawerBannerLoadingState extends State<_DrawerBannerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, _) {
        final pulse = (math.sin(_shimmer.value * math.pi * 2) + 1) / 2;
        final base = 0.08 + pulse * 0.10;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFF7B2CE0),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge skeleton
                Container(
                  width: 72,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: base + 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                // Quota text skeleton
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: base + 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                // Plan footer skeleton
                Container(
                  width: 130,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: base + 0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

PlanType _toPlanType(String? productId) {
  final id = productId?.toLowerCase() ?? '';
  if (id.contains('week')) return PlanType.weekly;
  if (id.contains('year')) return PlanType.yearly;
  return PlanType.monthly;
}

class _UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;

  const _UserAvatar({this.photoUrl, this.displayName});

  @override
  Widget build(BuildContext context) {
    final initial =
        (displayName?.isNotEmpty == true ? displayName![0] : null) ?? '?';

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: Colors.white.withValues(alpha: 0.20),
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (e, _) {},
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white.withValues(alpha: 0.20),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Drawer section ────────────────────────────────────────────────────────────

class _DrawerSection extends StatelessWidget {
  final String label;
  final Color labelColor;
  final List<_DrawerItem> items;

  const _DrawerSection({
    required this.label,
    required this.items,
    this.labelColor = AppColors.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(color: labelColor),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppShapes.cardRadius2,
            boxShadow: AppShapes.cardShadow,
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.hairline,
                    indent: 54,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Drawer item ───────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconBg;
  final Color textColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.iconBg = AppColors.purple600,
    this.textColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.cardRadius2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          spacing: 12,
          children: [
            _buildIconBox(),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 13,
              color: AppColors.muted2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: iconBg),
    );
  }
}
