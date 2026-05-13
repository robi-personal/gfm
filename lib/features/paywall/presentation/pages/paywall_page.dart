import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../cubit/subscription_cubit.dart';

// ── Palette (matches dashboard + ai_form_builder) ─────────────────────────────
const _purple = Color(0xFF772FC0);
const _purpleLight = Color(0xFFF3EBFC);
const _iosBg = Color(0xFFF2F2F7);
const _label1 = Color(0xFF1C1C1E);
const _label2 = Color(0xFF8E8E93);
const _saveBadge = Color(0xFF772FC0);

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
      backgroundColor: _iosBg,
      appBar: AppBar(
        backgroundColor: _iosBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'GFM Premium',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _label1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _purple),
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
      },
      builder: (context, state) {
        final offering = switch (state) {
          SubscriptionLoaded(offering: final o) => o,
          SubscriptionPurchasing(offering: final o) => o,
          _ => null,
        };
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
                          offering: offering,
                          onSelect: (p) => setState(() => _selected = p),
                        ),
                        const SizedBox(height: 28),

                        // Purchase button
                        _PurchaseButton(
                          label: _buttonLabel(_selected, offering),
                          enabled: !isPurchasing && !isLoading,
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
          color: _label2,
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
              color: _purpleLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _purple, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _label1,
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
  final ValueChanged<_Plan> onSelect;
  final Offering? offering;

  const _PricingSection({
    required this.selected,
    required this.onSelect,
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
          onTap: () => onSelect(_Plan.weekly),
        ),
        const SizedBox(width: 8),
        _FeaturedPlanCard(
          price: annualPrice,
          selected: selected == _Plan.annual,
          onTap: () => onSelect(_Plan.annual),
        ),
        const SizedBox(width: 8),
        _SidePlanCard(
          label: 'MONTHLY',
          price: monthlyPrice,
          perUnit: 'per month',
          selected: selected == _Plan.monthly,
          onTap: () => onSelect(_Plan.monthly),
        ),
      ],
    );
  }
}

class _FeaturedPlanCard extends StatelessWidget {
  final String price;
  final bool selected;
  final VoidCallback onTap;

  const _FeaturedPlanCard({
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              margin: const EdgeInsets.only(top: _badgeHeight / 2),
              padding: const EdgeInsets.fromLTRB(
                8,
                _badgeHeight / 2 + 14,
                8,
                18,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? _purpleLight.withValues(alpha: 0.6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _purple : const Color(0xFFDDD8E8),
                  width: selected ? 2 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _purple.withValues(alpha: 0.22),
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
                      color: selected ? _purple : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: selected ? _purple : _label1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'per year',
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? _purple.withValues(alpha: 0.7)
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
                color: _saveBadge,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Save 78%',
                style: TextStyle(
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
  final VoidCallback onTap;

  const _SidePlanCard({
    required this.label,
    required this.price,
    required this.perUnit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? _purpleLight.withValues(alpha: 0.6)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _purple : const Color(0xFFDDD8E8),
              width: selected ? 2 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.18),
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
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: selected ? _purple : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                price,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: selected ? _purple : _label1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perUnit,
                style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? _purple.withValues(alpha: 0.7)
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
          color: (enabled && !isLoading) ? _purple : const Color(0xFFD1D1D6),
          borderRadius: BorderRadius.circular(14),
          boxShadow: (enabled && !isLoading)
              ? [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.35),
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
                    color: enabled ? Colors.white : const Color(0xFF8E8E93),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onRestore,
          minimumSize: Size(0, 0),
          child: const Text(
            'Restore Purchases',
            style: TextStyle(
              fontSize: 13,
              color: _label2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
