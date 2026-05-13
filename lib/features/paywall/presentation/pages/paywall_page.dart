import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../cubit/subscription_cubit.dart';

// ── Palette (matches dashboard + ai_form_builder) ─────────────────────────────
const _purple      = Color(0xFF772FC0);
const _purpleLight = Color(0xFFF3EBFC);
const _iosBg       = Color(0xFFF2F2F7);
const _cardBg      = Colors.white;
const _label1      = Color(0xFF1C1C1E);
const _label2      = Color(0xFF8E8E93);
const _label3      = Color(0xFFC7C7CC);
const _divider     = Color(0xFFF2F2F7);
const _saveBadge   = Color(0xFFFF9500);

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
      child: const Scaffold(
        backgroundColor: _iosBg,
        body: _PaywallView(),
      ),
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
        _Plan.weekly  => offering.weekly,
        _Plan.annual  => offering.annual,
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
          SubscriptionLoaded(offering: final o)     => o,
          SubscriptionPurchasing(offering: final o) => o,
          _ => null,
        };
        final isPurchasing = state is SubscriptionPurchasing;
        final isLoading    = state is SubscriptionLoading || state is SubscriptionInitial;

        return Stack(
          children: [
            Column(
              children: [
                _NavBar(onClose: () => Navigator.of(context).pop()),
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
                        const _FeatureCard(),
                        const SizedBox(height: 20),

                        // Plan selector section
                        const _GroupLabel(text: 'SELECT YOUR PLAN'),
                        const SizedBox(height: 6),
                        _PlanCard(
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
                                body: 'Could not load subscription products. Please check your connection and try again.',
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
                          onRestore: () => context.read<SubscriptionCubit>().restore(),
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
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 14),
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
        final price  = pkg.storeProduct.priceString;
        final period = switch (plan) {
          _Plan.weekly  => 'week',
          _Plan.annual  => 'year',
          _Plan.monthly => 'month',
        };
        return 'Start Premium — $price / $period';
      }
    }
    return switch (plan) {
      _Plan.weekly  => 'Start Premium — \$3.99 / week',
      _Plan.annual  => 'Start Premium — \$44.99 / year',
      _Plan.monthly => 'Start Premium — \$4.99 / month',
    };
  }
}

// ── Nav bar ───────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final VoidCallback onClose;
  const _NavBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _iosBg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                'GFM Premium',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _label1,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: onClose,
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: _label3,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

// ── Feature card ──────────────────────────────────────────────────────────────

const _features = [
  (CupertinoIcons.bolt_fill,        Color(0xFF9B4FE8), 'AI Form Builder',       'Generate forms from text, PDF, YouTube'),
  (CupertinoIcons.arrow_clockwise,  Color(0xFF34C759), 'Unlimited Responses',   'View & refresh responses with no limits'),
  (CupertinoIcons.arrow_down_doc,   Color(0xFF007AFF), 'CSV Export',            'Export all responses to a spreadsheet'),
  (CupertinoIcons.star_fill,        _purple,           'All Future Features',   'Every new premium feature, included'),
];

class _FeatureCard extends StatelessWidget {
  const _FeatureCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
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
        children: [
          for (int i = 0; i < _features.length; i++) ...[
            _FeatureRow(
              icon:     _features[i].$1,
              color:    _features[i].$2,
              title:    _features[i].$3,
              subtitle: _features[i].$4,
            ),
            if (i < _features.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: _divider,
                indent: 54,
              ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _label1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _label2,
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

// ── Plan card (iOS grouped list) ──────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan selected;
  final ValueChanged<_Plan> onSelect;
  final Offering? offering;

  const _PlanCard({
    required this.selected,
    required this.onSelect,
    this.offering,
  });

  String _price(_Plan plan) {
    if (offering != null) {
      final pkg = switch (plan) {
        _Plan.weekly  => offering!.weekly,
        _Plan.monthly => offering!.monthly,
        _Plan.annual  => offering!.annual,
      };
      if (pkg != null) return pkg.storeProduct.priceString;
    }
    return switch (plan) {
      _Plan.weekly  => '\$3.99',
      _Plan.monthly => '\$4.99',
      _Plan.annual  => '\$44.99',
    };
  }

  String _period(_Plan plan) => switch (plan) {
        _Plan.weekly  => 'per week',
        _Plan.monthly => 'per month',
        _Plan.annual  => 'per year',
      };

  String _label(_Plan plan) => switch (plan) {
        _Plan.weekly  => 'Weekly',
        _Plan.monthly => 'Monthly',
        _Plan.annual  => 'Annual',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
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
        children: [
          for (int i = 0; i < _Plan.values.length; i++) ...[
            _PlanRow(
              label:    _label(_Plan.values[i]),
              price:    _price(_Plan.values[i]),
              period:   _period(_Plan.values[i]),
              isBest:   _Plan.values[i] == _Plan.annual,
              selected: selected == _Plan.values[i],
              onTap:    () => onSelect(_Plan.values[i]),
            ),
            if (i < _Plan.values.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: _divider,
                indent: 54,
              ),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final String price;
  final String period;
  final bool isBest;
  final bool selected;
  final VoidCallback onTap;

  const _PlanRow({
    required this.label,
    required this.price,
    required this.period,
    required this.isBest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: _purple.withValues(alpha: 0.06),
      highlightColor: _purple.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _purple : Colors.transparent,
                border: Border.all(
                  color: selected ? _purple : _label3,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 14),
            // Label + badge
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? _purple : _label1,
                    ),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _saveBadge.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Save 78%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _saveBadge,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected ? _purple : _label1,
                  ),
                ),
                Text(
                  period,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _label2,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 2),
          ],
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
              ? const CupertinoActivityIndicator(color: Colors.white, radius: 11)
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
          minSize: 0,
          onPressed: onRestore,
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
