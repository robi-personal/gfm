import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/widgets/error_modal.dart';
import '../../../../../core/widgets/simple_web_view_page.dart';
import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../../ai_form_builder/data/services/user_status_service.dart';
import '../../../ai_form_builder/presentation/widgets/ai_quota_counter.dart';
import '../../../ai_form_builder/presentation/widgets/premium_banner.dart';

const _kAppStoreId = '6479591930';
const _kAppStoreReviewUrl =
    'itms-apps://itunes.apple.com/app/id$_kAppStoreId?action=write-review';

/// Our other apps — shown as a horizontal row of tiles in the drawer.
/// Icons are loaded from the App Store CDN so there are no bundled assets.
const _kMoreApps = <_MoreApp>[
  _MoreApp(
    name: 'Dopamin Detox',
    iconUrl:
        'https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/0c/18/de/0c18de7f-edd1-edc1-6a32-e0916e1b333f/AppIcon-0-0-1x_U007ephone-0-1-85-220.png/256x256bb.jpg',
    storeUrl:
        'https://apps.apple.com/us/app/dopamin-detox-block-focus/id6780148393',
  ),
  _MoreApp(
    name: 'WASticker',
    iconUrl:
        'https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/a0/45/97/a04597da-c940-a931-a940-9b85ee02ed57/AppIcon-0-0-1x_U007epad-0-11-0-0-85-220.png/256x256bb.jpg',
    storeUrl:
        'https://apps.apple.com/us/app/wasticker-ai-sticker-maker/id6754502041',
  ),
  _MoreApp(
    name: 'Aquarium',
    iconUrl:
        'https://is1-ssl.mzstatic.com/image/thumb/Purple128/v4/03/a0/d4/03a0d41f-19f5-8ecf-4f78-baf7dabe4b4c/AppIcon-1x_U007emarketing-85-220-0-4.png/256x256bb.jpg',
    storeUrl:
        'https://apps.apple.com/us/app/aquarium-live-wallpapers-lite/id1194959293',
  ),
  _MoreApp(
    name: 'Lipers',
    iconUrl:
        'https://is1-ssl.mzstatic.com/image/thumb/Purple118/v4/22/f5/4f/22f54f9d-8bda-0960-09e0-5713fc3b9c99/AppIcon-1x_U007emarketing-85-220-0-4.png/256x256bb.jpg',
    storeUrl:
        'https://apps.apple.com/us/app/lipers-lite-live-wallpapers/id1181075088',
  ),
];

class _MoreApp {
  final String name;
  final String iconUrl;
  final String storeUrl;

  const _MoreApp({
    required this.name,
    required this.iconUrl,
    required this.storeUrl,
  });
}

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
    final service = getIt<UserStatusService>();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final status = service.status;

        if (status == null) {
          return Column(
            children: [
              _DrawerHeader(topPad: topPad),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
                  children: [_buildSections(context)],
                ),
              ),
            ],
          );
        }

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

        final header = status.isPremium
            ? PremiumBanner(
                generationsLeft: status.quotaBalance,
                currentPlan: _toPlanType(status.subscriptionProductId),
                showAnimations: true,
                showBorderShimmer: false,
                showFooter: false,
                showRefreshButton: false,
                borderRadius: BorderRadius.zero,
                topPadding: topPad,
                userName: displayName,
                userEmail: email,
                userPhotoUrl: photoUrl,
                onRefresh: () => service.refresh(),
              )
            : AiQuotaCounter(
                status: status,
                topPadding: topPad,
                userName: displayName,
                userEmail: email,
                userPhotoUrl: photoUrl,
                onUpgradeTap: onShowPaywall,
              );

        return Column(
          children: [
            header,
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.paddingOf(context).bottom),
                children: [_buildSections(context)],
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
                Scaffold.of(context).closeDrawer();
                onAiBuilder();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.pencil,
              title: 'Create Form',
              onTap: () {
                Scaffold.of(context).closeDrawer();
                onCreateForm();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.arrow_down_circle,
              title: 'Import Form',
              onTap: () {
                Scaffold.of(context).closeDrawer();
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
                Scaffold.of(context).closeDrawer();
                onShowPaywall();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.arrow_clockwise,
              title: 'Restore Purchases',
              onTap: () {
                Scaffold.of(context).closeDrawer();
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
                Scaffold.of(context).closeDrawer();
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
                Scaffold.of(context).closeDrawer();
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
                Scaffold.of(context).closeDrawer();
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
        const _MoreAppsSection(),
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
                Scaffold.of(context).closeDrawer();
                context.read<SignInCubit>().signOut();
              },
            ),
            _DrawerItem(
              icon: CupertinoIcons.trash,
              title: 'Delete Account',
              iconBg: AppColors.error,
              textColor: AppColors.error,
              onTap: () {
                Scaffold.of(context).closeDrawer();
                _showDeleteAccountSheet(context);
              },
            ),
          ],
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
      padding: EdgeInsets.only(top: topPad, bottom: 28, left: 20, right: 20),
      child: BlocSelector<
          SignInCubit,
          SignInState,
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
            _UserAvatar(
              photoUrl: user.photoUrl,
              displayName: user.displayName,
            ),
            Expanded(child: _buildUserInfo(user)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(
    ({String? displayName, String? photoUrl, String email}) user,
  ) {
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

// ── Helpers ───────────────────────────────────────────────────────────────────

PlanType _toPlanType(String? productId) {
  final id = productId?.toLowerCase() ?? '';
  if (id.contains('weekly')) return PlanType.weekly;
  if (id.contains('yearly')) return PlanType.yearly;
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

// ── Our more apps ─────────────────────────────────────────────────────────────

class _MoreAppsSection extends StatelessWidget {
  const _MoreAppsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'OUR MORE APPS',
            style: AppTextStyles.sectionLabel.copyWith(color: AppColors.muted),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppShapes.cardRadius2,
            boxShadow: AppShapes.cardShadow,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                for (final app in _kMoreApps) _MoreAppTile(app: app),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreAppTile extends StatelessWidget {
  final _MoreApp app;

  const _MoreAppTile({required this.app});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(app.storeUrl),
        mode: LaunchMode.externalApplication,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  app.iconUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 52,
                    height: 52,
                    color: AppColors.purple600.withValues(alpha: 0.12),
                    child: Icon(
                      CupertinoIcons.app_fill,
                      size: 22,
                      color: AppColors.purple600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delete account sheet ──────────────────────────────────────────────────────

void _showDeleteAccountSheet(BuildContext ctx) {
  final cubit = ctx.read<SignInCubit>();
  // Capture the root navigator state — its context survives drawer/sheet
  // teardown and the auth-gate page swap on sign-out.
  final rootNav = Navigator.of(ctx, rootNavigator: true);
  showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeleteAccountSheet(
      onConfirm: cubit.deleteAccount,
      onError: () {
        if (!rootNav.mounted) return;
        ErrorModal.show(
          rootNav.context,
          title: 'Something went wrong',
          body: 'Could not schedule account deletion. Please try again.',
          primaryLabel: 'OK',
          onPrimary: () {},
        );
      },
    ),
  );
}

class _DeleteAccountSheet extends StatefulWidget {
  final Future<void> Function() onConfirm;
  final VoidCallback onError;

  const _DeleteAccountSheet({required this.onConfirm, required this.onError});

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _controller = TextEditingController();
  bool _confirmed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final match = _controller.text == 'DELETE';
      if (match != _confirmed) setState(() => _confirmed = match);
    });
  }

  Future<void> _handleConfirm() async {
    setState(() => _loading = true);
    try {
      // Run the API call alongside a minimum-display delay so the spinner
      // is always visible long enough to register, even on a fast network.
      await Future.wait<void>([
        widget.onConfirm(),
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
      // Sign-out swaps the home page but the modal sheet route stays on
      // the navigator stack — pop it explicitly so it does not hover over
      // the sign-in screen.
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onError();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(CupertinoIcons.trash, color: AppColors.error, size: 24),
          ),
          const SizedBox(height: 16),
          const Text(
            'Delete Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your account and all data will be permanently deleted after 30 days. Sign in again any time within 30 days to cancel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Type DELETE to confirm',
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.muted2,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: Size.zero,
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.bg,
                  pressedOpacity: 0.7,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoButton(
                  onPressed: (_confirmed && !_loading) ? _handleConfirm : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: Size.zero,
                  borderRadius: BorderRadius.circular(12),
                  color: _confirmed ? AppColors.error : AppColors.error.withValues(alpha: 0.35),
                  pressedOpacity: 0.8,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple),
                          ),
                        )
                      : const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
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
