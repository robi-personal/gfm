import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../cubit/subscription_cubit.dart';

const _purple = Color(0xFF772FC0);
const _purpleLight = Color(0xFFF3EBFC);
const _saveBadge = Color(0xFFE53935);
const _darkText = Color(0xFF1A1A2E);

// ── Entry point ────────────────────────────────────────────────────────────────

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
      child: const Scaffold(
        backgroundColor: Colors.white,
        body: _PaywallView(),
      ),
    );
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

enum _Plan { weekly, annual, monthly }

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
                _Header(onClose: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const _Illustration(),
                        const SizedBox(height: 24),
                        const _SectionLabel(
                          text: "Select your plan",
                          fontSize: 18,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Divider(),
                        ),
                        const SizedBox(height: 16),
                        _PricingSection(
                          selected: _selected,
                          offering: offering,
                          onSelect: (p) => setState(() => _selected = p),
                        ),
                        const SizedBox(height: 20),
                        const _SectionLabel(text: "What's included",fontSize: 16,),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: const Divider(),
                        ),
                        const SizedBox(height: 12),
                        const _FeatureList(),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
                _PurchaseButton(
                  label: _buttonLabel(_selected, offering),
                  enabled: !isPurchasing && !isLoading,
                  isLoading: isLoading,
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
                  bottomPadding: bottom,
                ),
              ],
            ),
            if (isPurchasing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55FFFFFF),
                  child: Center(
                    child: CircularProgressIndicator(color: _purple),
                  ),
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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'Become Premium',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _darkText,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                color: Colors.grey[600],
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Illustration ───────────────────────────────────────────────────────────────

class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/paywall_banner.svg',
      height: 160,
      fit: BoxFit.contain,
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final double fontSize;

  const _SectionLabel({required this.text, this.fontSize = 13.0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Feature list ───────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  static const _features = [
    'Unlimited form creation',
    'Import forms',
    'Unlimited response refreshes',
    'Export responses as CSV',
    'All future premium features',
  ];

  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: _features.map((f) => _FeatureRow(label: f)).toList(),
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
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: _purpleLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _purple, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing section ────────────────────────────────────────────────────────────

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
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
      ),
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
                      color: selected ? _purple : _darkText,
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
                  color: selected ? _purple : _darkText,
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

class _FooterLink extends StatelessWidget {
  final String label;
  final bool bold;
  final VoidCallback onTap;

  const _FooterLink({
    required this.label,
    required this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: _purple,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

// ── Purchase button ────────────────────────────────────────────────────────────

class _PurchaseButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;
  final double bottomPadding;

  const _PurchaseButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.bottomPadding,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0EAF8), width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: _purple,
          disabledBackgroundColor: _purple.withValues(alpha: 0.5),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(label),
      ),
    );
  }
}
