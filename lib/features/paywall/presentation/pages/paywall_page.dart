import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../../core/widgets/simple_web_view_page.dart';
import '../cubit/subscription_cubit.dart';

// Apple requires a visible link to manage/cancel during purchase flow.
const _manageSubscriptionsUrl = 'https://apps.apple.com/account/subscriptions';
const _privacyUrl = 'https://gformmanager.netlify.app/privacy';
const _termsUrl   = 'https://gformmanager.netlify.app/terms';

// ── Entry point ───────────────────────────────────────────────────────────────

class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const PaywallPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SubscriptionCubit>()..load(),
      child: const _PaywallScaffold(),
    );
  }
}

class _PaywallScaffold extends StatelessWidget {
  const _PaywallScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'GFM Premium',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.purple),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const _PaywallView(),
    );
  }
}

// ── Plan enum ─────────────────────────────────────────────────────────────────

enum _Plan { weekly, annual, monthly }

// ── Main view ─────────────────────────────────────────────────────────────────

class _PaywallView extends StatefulWidget {
  const _PaywallView();

  @override
  State<_PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<_PaywallView> {
  _Plan _selected = _Plan.annual;

  Package? _packageFor(_Plan plan, Offering offering) => switch (plan) {
    _Plan.weekly => offering.weekly,
    _Plan.annual => offering.annual,
    _Plan.monthly => offering.monthly,
  };

  _Plan? _currentPlan(String? productId, Offering? offering) {
    if (productId == null) return null;
    if (productId == offering?.weekly?.storeProduct.identifier) return _Plan.weekly;
    if (productId == offering?.monthly?.storeProduct.identifier) return _Plan.monthly;
    if (productId == offering?.annual?.storeProduct.identifier) return _Plan.annual;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return BlocConsumer<SubscriptionCubit, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionLoaded && state.justPurchased) {
          Navigator.of(context).pop();
        }
        if (state is SubscriptionError) {
          ErrorModal.show(
            context,
            title: 'Purchase failed',
            body: state.message,
            primaryLabel: 'OK',
            onPrimary: () {},
          );
        }
        if (state is SubscriptionAppleBindingConflict) {
          final cubit = context.read<SubscriptionCubit>();
          ErrorModal.show(
            context,
            title: 'Apple ID already linked',
            body: state.message,
            primaryLabel: 'OK',
            onPrimary: cubit.resetAfterConflict,
          );
        }
      },
      builder: (context, state) {
        final offering = switch (state) {
          SubscriptionLoaded(offering: final o) => o,
          SubscriptionPurchasing(offering: final o) => o,
          SubscriptionAppleBindingConflict(offering: final o) => o,
          _ => null,
        };
        final currentProductId = state is SubscriptionLoaded ? state.currentProductId : null;
        final currentPlan = _currentPlan(currentProductId, offering);
        final isPurchasing = state is SubscriptionPurchasing;
        final isLoading =
            state is SubscriptionLoading || state is SubscriptionInitial;

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottom),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Illustration
                        Center(
                          child: SvgPicture.asset(
                            'assets/paywall_banner.svg',
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Features section
                        const _GroupLabel(text: "WHAT'S INCLUDED"),
                        const SizedBox(height: 6),
                        _FeatureCard(selected: _selected),
                        const SizedBox(height: 20),

                        // Plan selector section
                        const _GroupLabel(text: 'SELECT YOUR PLAN'),
                        const SizedBox(height: 6),
                        _PricingSection(
                          selected: _selected,
                          currentPlan: currentPlan,
                          offering: offering,
                          onSelect: (p) => setState(() => _selected = p),
                        ),
                        const SizedBox(height: 28),

                        // Purchase button
                        _PurchaseButton(
                          label: _selected == currentPlan
                              ? 'Current Plan'
                              : _buttonLabel(_selected, offering),
                          enabled: !isPurchasing && !isLoading && _selected != currentPlan,
                          isLoading: isLoading || isPurchasing,
                          onTap: () {
                            final package = offering != null
                                ? _packageFor(_selected, offering)
                                : null;
                            if (package == null) {
                              ErrorModal.show(
                                context,
                                title: 'Products unavailable',
                                body:
                                    'Could not load subscription products. Please check your connection and try again.',
                                primaryLabel: 'OK',
                                onPrimary: () {},
                              );
                              return;
                            }
                            context.read<SubscriptionCubit>().purchase(package);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Footer
                        _Footer(
                          onRestore: () =>
                              context.read<SubscriptionCubit>().restore(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isPurchasing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55FFFFFF),
                  child: Center(child: CupertinoActivityIndicator(radius: 14)),
                ),
              ),
          ],
        );
      },
    );
  }

  String _buttonLabel(_Plan plan, Offering? offering) {
    if (offering != null) {
      final pkg = _packageFor(plan, offering);
      if (pkg != null) {
        final price = pkg.storeProduct.priceString;
        final period = switch (plan) {
          _Plan.weekly => 'week',
          _Plan.annual => 'year',
          _Plan.monthly => 'month',
        };
        return 'Start Premium — $price / $period';
      }
    }
    return switch (plan) {
      _Plan.weekly => 'Start Premium — \$3.99 / week',
      _Plan.annual => 'Start Premium — \$44.99 / year',
      _Plan.monthly => 'Start Premium — \$4.99 / month',
    };
  }
}

// ── Group label (iOS settings style) ─────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Feature list ─────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final _Plan selected;

  const _FeatureCard({required this.selected});

  String get _quotaLine => switch (selected) {
    _Plan.weekly => '15 AI generations per week',
    _Plan.monthly => '50 AI generations per month',
    _Plan.annual => '600 AI generations per year',
  };

  @override
  Widget build(BuildContext context) {
    final features = [
      'AI Form builder',
      'Unlimited Manual Form build',
      'Unlimited response refreshes',
      'Export responses as CSV',
      'All future premium features',
      _quotaLine,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: features.map((f) => _FeatureRow(label: f)).toList(),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;

  const _FeatureRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.purpleTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.purple, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing section (3-card layout) ──────────────────────────────────────────

const _badgeHeight = 26.0;

class _PricingSection extends StatelessWidget {
  final _Plan selected;
  final _Plan? currentPlan;
  final ValueChanged<_Plan> onSelect;
  final Offering? offering;

  const _PricingSection({
    required this.selected,
    required this.onSelect,
    this.currentPlan,
    this.offering,
  });

  @override
  Widget build(BuildContext context) {
    final weeklyPrice = offering?.weekly?.storeProduct.priceString ?? '\$3.99';
    final annualPrice = offering?.annual?.storeProduct.priceString ?? '\$44.99';
    final monthlyPrice =
        offering?.monthly?.storeProduct.priceString ?? '\$4.99';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SidePlanCard(
          label: 'WEEKLY',
          price: weeklyPrice,
          perUnit: 'per week',
          selected: selected == _Plan.weekly,
          isCurrent: currentPlan == _Plan.weekly,
          onTap: () => onSelect(_Plan.weekly),
        ),
        const SizedBox(width: 8),
        _FeaturedPlanCard(
          price: annualPrice,
          selected: selected == _Plan.annual,
          isCurrent: currentPlan == _Plan.annual,
          onTap: () => onSelect(_Plan.annual),
        ),
        const SizedBox(width: 8),
        _SidePlanCard(
          label: 'MONTHLY',
          price: monthlyPrice,
          perUnit: 'per month',
          selected: selected == _Plan.monthly,
          isCurrent: currentPlan == _Plan.monthly,
          onTap: () => onSelect(_Plan.monthly),
        ),
      ],
    );
  }
}

class _FeaturedPlanCard extends StatelessWidget {
  final String price;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _FeaturedPlanCard({
    required this.price,
    required this.selected,
    required this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final badgeLabel = isCurrent ? 'Current' : 'Save 78%';
    final badgeColor = isCurrent ? AppColors.textSecondary : AppColors.purple;

    return Expanded(
      child: GestureDetector(
        onTap: isCurrent ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              margin: const EdgeInsets.only(top: _badgeHeight / 2),
              padding: const EdgeInsets.fromLTRB(8, _badgeHeight / 2 + 14, 8, 18),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFFF2F2F7)
                    : selected
                        ? AppColors.purpleTint.withValues(alpha: 0.6)
                        : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFFDDD8E8)
                      : selected
                          ? AppColors.purple
                          : const Color(0xFFDDD8E8),
                  width: selected && !isCurrent ? 2 : 1.5,
                ),
                boxShadow: selected && !isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ANNUAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isCurrent
                          ? AppColors.textSecondary
                          : selected
                              ? AppColors.purple
                              : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isCurrent
                          ? AppColors.textSecondary
                          : selected
                              ? AppColors.purple
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'per year',
                    style: TextStyle(
                      fontSize: 10,
                      color: isCurrent
                          ? AppColors.textSecondary.withValues(alpha: 0.7)
                          : selected
                              ? AppColors.purple.withValues(alpha: 0.7)
                              : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: _badgeHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidePlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String perUnit;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _SidePlanCard({
    required this.label,
    required this.price,
    required this.perUnit,
    required this.selected,
    required this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isCurrent ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0xFFF2F2F7)
                : selected
                    ? AppColors.purpleTint.withValues(alpha: 0.6)
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFDDD8E8)
                  : selected
                      ? AppColors.purple
                      : const Color(0xFFDDD8E8),
              width: selected && !isCurrent ? 2 : 1.5,
            ),
            boxShadow: selected && !isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCurrent ? 'CURRENT' : label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isCurrent
                      ? AppColors.textSecondary
                      : selected
                          ? AppColors.purple
                          : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                price,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isCurrent
                      ? AppColors.textSecondary
                      : selected
                          ? AppColors.purple
                          : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perUnit,
                style: TextStyle(
                  fontSize: 10,
                  color: isCurrent
                      ? AppColors.textSecondary.withValues(alpha: 0.7)
                      : selected
                          ? AppColors.purple.withValues(alpha: 0.7)
                          : Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Purchase button ───────────────────────────────────────────────────────────

class _PurchaseButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _PurchaseButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (enabled && !isLoading) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: (enabled && !isLoading) ? AppColors.purple : AppColors.iconInactive,
          borderRadius: BorderRadius.circular(14),
          boxShadow: (enabled && !isLoading)
              ? [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 11,
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.white : AppColors.textSecondary,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final VoidCallback onRestore;

  const _Footer({required this.onRestore});

  void _open(BuildContext context, String url, String title) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SimpleWebViewPage(title: title, url: url),
      ));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Auto-renewal disclosure (Apple App Store guideline 3.1.2).
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Subscription auto-renews at the end of each period. '
            'Cancel anytime in App Store settings at least 24 hours before the renewal date. '
            'Payment is charged to your Apple ID account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FooterLink(label: 'Restore Purchases', onTap: onRestore),
            const _FooterDot(),
            _FooterLink(
              label: 'Manage Subscription',
              onTap: () => launchUrl(Uri.parse(_manageSubscriptionsUrl),
                  mode: LaunchMode.externalApplication),
            ),
            const _FooterDot(),
            _FooterLink(
              label: 'Privacy Policy',
              onTap: () => _open(context, _privacyUrl, 'Privacy Policy'),
            ),
            const _FooterDot(),
            _FooterLink(
              label: 'Terms of Use',
              onTap: () => _open(context, _termsUrl, 'Terms of Use'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      onPressed: onTap,
      minimumSize: Size.zero,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  const _FooterDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '·',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}
