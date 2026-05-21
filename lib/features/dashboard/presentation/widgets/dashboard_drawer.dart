import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design.dart';
import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';

class DashboardDrawer extends StatelessWidget {
  final VoidCallback onAiBuilder;
  final VoidCallback onCreateForm;
  final VoidCallback onImportForm;
  final VoidCallback onShowPaywall;

  const DashboardDrawer({
    super.key,
    required this.onAiBuilder,
    required this.onCreateForm,
    required this.onImportForm,
    required this.onShowPaywall,
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
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final VoidCallback onAiBuilder;
  final VoidCallback onCreateForm;
  final VoidCallback onImportForm;
  final VoidCallback onShowPaywall;

  const _DrawerContent({
    required this.onAiBuilder,
    required this.onCreateForm,
    required this.onImportForm,
    required this.onShowPaywall,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 20.0;

    return Column(
      children: [
        _DrawerHeader(topPad: topPad),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            children: [
              _DrawerSection(
                label: 'CREATE',
                items: [
                  _DrawerItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Form Builder',
                    onTap: () { Navigator.of(context).pop(); onAiBuilder(); },
                  ),
                  _DrawerItem(
                    icon: CupertinoIcons.pencil,
                    title: 'Create Form',
                    onTap: () { Navigator.of(context).pop(); onCreateForm(); },
                  ),
                  _DrawerItem(
                    icon: CupertinoIcons.arrow_down_circle,
                    title: 'Import Form',
                    onTap: () { Navigator.of(context).pop(); onImportForm(); },
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
                    onTap: () { Navigator.of(context).pop(); onShowPaywall(); },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DrawerSection(
                label: 'SUPPORT US',
                items: [
                  _DrawerItem(
                    icon: CupertinoIcons.share,
                    title: 'Share on the App Store',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _DrawerItem(
                    icon: CupertinoIcons.hand_thumbsup,
                    title: 'Rate the app',
                    onTap: () => Navigator.of(context).pop(),
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
                      launchUrl(
                        Uri.parse('https://gformmanager.netlify.app/privacy'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: CupertinoIcons.doc_text,
                    title: 'Terms of Use',
                    onTap: () {
                      Navigator.of(context).pop();
                      launchUrl(
                        Uri.parse('https://gformmanager.netlify.app/terms'),
                        mode: LaunchMode.externalApplication,
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
          ),
        ),
      ],
    );
  }
}

// ── Drawer header ─────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final double topPad;

  const _DrawerHeader({required this.topPad});

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
      padding: EdgeInsets.only(
        top: topPad,
        bottom: 28,
        left: 20,
        right: 20,
      ),
      child: BlocSelector<SignInCubit, SignInState,
          ({String? displayName, String? photoUrl, String email})>(
        selector: (state) => state is Authenticated
            ? (
                displayName: state.user.displayName,
                photoUrl: state.user.photoUrl,
                email: state.user.email,
              )
            : (displayName: null, photoUrl: null, email: ''),
        builder: (context, user) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 12,
          children: [
            _UserAvatar(photoUrl: user.photoUrl, displayName: user.displayName),
            Expanded(child: _buildUserInfo(user)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(
      ({String? displayName, String? photoUrl, String email}) user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.displayName != null)
          Text(
            user.displayName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (user.email.isNotEmpty)
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
            ),
          ),
      ],
    );
  }
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
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 13, color: AppColors.muted2),
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
