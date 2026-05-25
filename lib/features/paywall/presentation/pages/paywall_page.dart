import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../../core/widgets/simple_web_view_page.dart';
import '../cubit/subscription_cubit.dart';

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

// ── Scaffold ──────────────────────────────────────────────────────────────────

class _PaywallScaffold extends StatelessWidget {
  const _PaywallScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: _PaywallView(),
    );
  }
}

// ── Plan enum ─────────────────────────────────────────────────────────────────

enum _Plan { weekly, monthly, annual }

// ── Main view ─────────────────────────────────────────────────────────────────

class _PaywallView extends StatefulWidget {
  const _PaywallView();

  @override
  State<_PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<_PaywallView> {
  _Plan _selected = _Plan.monthly;

  Package? _packageFor(_Plan plan, Offering offering) => switch (plan) {
    _Plan.weekly  => offering.weekly,
    _Plan.monthly => offering.monthly,
    _Plan.annual  => offering.annual,
  };

  _Plan? _currentPlan(String? productId, Offering? offering) {
    if (productId == null) return null;
    if (productId == offering?.weekly?.storeProduct.identifier)  return _Plan.weekly;
    if (productId == offering?.monthly?.storeProduct.identifier) return _Plan.monthly;
    if (productId == offering?.annual?.storeProduct.identifier)  return _Plan.annual;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

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
          SubscriptionLoaded(offering: final o)              => o,
          SubscriptionPurchasing(offering: final o)          => o,
          SubscriptionAppleBindingConflict(offering: final o) => o,
          _ => null,
        };
        final currentProductId = state is SubscriptionLoaded ? state.currentProductId : null;
        final currentPlan  = _currentPlan(currentProductId, offering);
        final isPurchasing = state is SubscriptionPurchasing;
        final isLoading    = state is SubscriptionLoading || state is SubscriptionInitial;

        final weeklyPrice  = offering?.weekly?.storeProduct.priceString  ?? '\$3.99';
        final monthlyPrice = offering?.monthly?.storeProduct.priceString ?? '\$9.99';
        final annualPrice  = offering?.annual?.storeProduct.priceString  ?? '\$59.99';

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Close button
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.xmark,
                                size: 14,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Header icon
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.purple500, AppColors.purple700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple600.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        const Text(
                          'Go Premium',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Unlock everything. Cancel anytime.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Plan tiles
                        _PlanTile(
                          plan: _Plan.weekly,
                          label: 'Weekly',
                          price: weeklyPrice,
                          period: 'week',
                          selected: _selected == _Plan.weekly,
                          isCurrent: currentPlan == _Plan.weekly,
                          onTap: () => setState(() => _selected = _Plan.weekly),
                        ),
                        const SizedBox(height: 10),
                        _PlanTile(
                          plan: _Plan.monthly,
                          label: 'Monthly',
                          price: monthlyPrice,
                          period: 'month',
                          saveText: 'Save 37% vs weekly',
                          badge: 'MOST POPULAR',
                          selected: _selected == _Plan.monthly,
                          isCurrent: currentPlan == _Plan.monthly,
                          onTap: () => setState(() => _selected = _Plan.monthly),
                        ),
                        const SizedBox(height: 10),
                        _PlanTile(
                          plan: _Plan.annual,
                          label: 'Yearly',
                          price: annualPrice,
                          period: 'year',
                          saveText: 'Best value · Save 50%',
                          selected: _selected == _Plan.annual,
                          isCurrent: currentPlan == _Plan.annual,
                          onTap: () => setState(() => _selected = _Plan.annual),
                        ),
                        const SizedBox(height: 24),

                        // Continue button
                        _ContinueButton(
                          enabled: !isPurchasing && !isLoading && _selected != currentPlan,
                          isLoading: isLoading || isPurchasing,
                          isCurrent: _selected == currentPlan,
                          onTap: () {
                            final package = offering != null
                                ? _packageFor(_selected, offering)
                                : null;
                            if (package == null) {
                              ErrorModal.show(
                                context,
                                title: 'Products unavailable',
                                body: 'Could not load subscription products. Please check your connection and try again.',
                                primaryLabel: 'OK',
                                onPrimary: () {},
                              );
                              return;
                            }
                            context.read<SubscriptionCubit>().purchase(package);
                          },
                        ),
                        const SizedBox(height: 32),

                        // What's included
                        const _SectionLabel(text: "WHAT'S INCLUDED"),
                        const SizedBox(height: 12),
                        const _FeaturesList(),
                        const SizedBox(height: 24),

                        // Footer
                        _Footer(
                          onRestore: () => context.read<SubscriptionCubit>().restore(),
                        ),
                        SizedBox(height: 24 + bottomPad),
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
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Plan tile (vertical stacked) ──────────────────────────────────────────────

const _badgeH = 24.0;

class _PlanTile extends StatelessWidget {
  final _Plan plan;
  final String label;
  final String price;
  final String period;
  final String? saveText;
  final String? badge;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.label,
    required this.price,
    required this.period,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
    this.saveText,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badge != null;

    return GestureDetector(
      onTap: isCurrent ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: EdgeInsets.only(top: hasBadge ? _badgeH / 2 : 0),
            padding: EdgeInsets.fromLTRB(
              16,
              hasBadge ? _badgeH / 2 + 14 : 16,
              16,
              16,
            ),
            decoration: BoxDecoration(
              color: selected && !isCurrent
                  ? AppColors.purple50
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? AppColors.hairline
                    : selected
                        ? AppColors.purple600
                        : AppColors.hairline,
                width: selected && !isCurrent ? 2 : 1.5,
              ),
              boxShadow: selected && !isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.purple600.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrent ? '$label (Current)' : label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? AppColors.muted
                              : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isCurrent
                                  ? AppColors.muted
                                  : selected
                                      ? AppColors.purple600
                                      : AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '/ $period',
                            style: TextStyle(
                              fontSize: 13,
                              color: isCurrent
                                  ? AppColors.muted2
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (saveText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          saveText!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isCurrent
                                ? AppColors.muted2
                                : AppColors.purple600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _RadioIndicator(selected: selected, isCurrent: isCurrent),
              ],
            ),
          ),
          if (hasBadge)
            Container(
              height: _badgeH,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple500, AppColors.purple700],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool selected;
  final bool isCurrent;

  const _RadioIndicator({required this.selected, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    if (isCurrent) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline, width: 2),
        ),
      );
    }
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.purple600,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.muted2, width: 2),
      ),
    );
  }
}

// ── Continue button ───────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.enabled,
    required this.isLoading,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isCurrent ? 'Current Plan' : 'Continue';

    return GestureDetector(
      onTap: (enabled && !isLoading) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 54,
        decoration: BoxDecoration(
          gradient: (enabled && !isLoading)
              ? const LinearGradient(
                  colors: [AppColors.purple500, AppColors.purple700],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: (enabled && !isLoading) ? null : AppColors.iconInactive,
          borderRadius: BorderRadius.circular(16),
          boxShadow: (enabled && !isLoading)
              ? [
                  BoxShadow(
                    color: AppColors.purple600.withValues(alpha: 0.40),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const CupertinoActivityIndicator(color: Colors.white, radius: 11)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : AppColors.muted,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Features list ─────────────────────────────────────────────────────────────

class _FeaturesList extends StatelessWidget {
  const _FeaturesList();

  static const _features = [
    (
      icon: CupertinoIcons.sparkles,
      title: 'Unlimited AI generations',
      subtitle: 'Build as many AI forms as you need, every day.',
    ),
    (
      icon: CupertinoIcons.pencil_outline,
      title: 'Unlimited manual form build',
      subtitle: 'Create and edit forms without any restrictions.',
    ),
    (
      icon: CupertinoIcons.arrow_clockwise,
      title: 'Unlimited response refreshes',
      subtitle: 'Sync responses as often as you like.',
    ),
    (
      icon: CupertinoIcons.arrow_down_doc,
      title: 'Export responses as CSV',
      subtitle: 'Download your data anytime in spreadsheet format.',
    ),
    (
      icon: CupertinoIcons.bell,
      title: 'Push notifications',
      subtitle: 'Get notified instantly when a new response arrives.',
    ),
    (
      icon: CupertinoIcons.star,
      title: 'All future premium features',
      subtitle: 'Every new feature we ship — yours automatically.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _features.length; i++) ...[
            _FeatureRow(
              icon: _features[i].icon,
              title: _features[i].title,
              subtitle: _features[i].subtitle,
            ),
            if (i < _features.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.hairline, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.purple50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.purple600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.4,
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
        const Text(
          'Payment will be charged to your Apple ID account. Subscription automatically renews unless auto-renewal is turned off at least 24 hours before the end of the current period.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FooterLink(
              label: 'Privacy Policy',
              onTap: () => _open(context, _privacyUrl, 'Privacy Policy'),
            ),
            const _FooterDot(),
            _FooterLink(
              label: 'Terms of Use',
              onTap: () => _open(context, _termsUrl, 'Terms of Use'),
            ),
            const _FooterDot(),
            _FooterLink(label: 'Restore Purchase', onTap: onRestore),
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
          color: AppColors.purple600,
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
      child: Text('·', style: TextStyle(color: AppColors.muted, fontSize: 12)),
    );
  }
}
