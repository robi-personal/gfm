import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _purple = Color(0xFF772FC0);
const _purpleLight = Color(0xFFF3EBFC);
const _saveBadge = Color(0xFFE53935);

// ── Entry point ────────────────────────────────────────────────────────────────

class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  /// Push as a full-screen modal.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const PaywallPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: _PaywallView(),
    );
  }
}

// ── Main view (stateful for plan selection) ────────────────────────────────────

enum _Plan { weekly, annual, monthly }

class _PaywallView extends StatefulWidget {
  const _PaywallView();

  @override
  State<_PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<_PaywallView> {
  _Plan _selected = _Plan.annual;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onClose: () => Navigator.of(context).pop()),
                _Illustration(),
                const SizedBox(height: 20),
                _FeatureList(),
                const SizedBox(height: 24),
                _PricingSection(
                  selected: _selected,
                  onSelect: (p) => setState(() => _selected = p),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        _PurchaseButton(
          plan: _selected,
          onTap: () {/* IAP hook */},
          bottomPadding: bottom,
        ),
      ],
    );
  }
}

// ── Header with close button ───────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.close),
            color: Colors.grey[600],
            onPressed: onClose,
          ),
        ),
      ),
    );
  }
}

// ── Illustration ───────────────────────────────────────────────────────────────

class _Illustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/login_banner.svg',
      height: 180,
      fit: BoxFit.contain,
    );
  }
}

// ── Feature list ───────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  static const _features = [
    'Unlimited response refreshes',
    'Advanced question types (Scale, Date, Rating, Grid)',
    'Download responses as CSV & Excel',
    'Export responses to Google Sheets',
    'All future premium features',
    'Remove ads',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: _features
            .map((f) => _FeatureRow(label: f))
            .toList(),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: _purpleLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: _purple, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing section ────────────────────────────────────────────────────────────

const _badgeHeight = 26.0; // height of the save badge pill

class _PricingSection extends StatelessWidget {
  final _Plan selected;
  final ValueChanged<_Plan> onSelect;

  const _PricingSection({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Weekly — side card
          _SidePlanCard(
            label: 'WEEKLY',
            price: '\$1.99',
            perUnit: 'per week',
            selected: selected == _Plan.weekly,
            onTap: () => onSelect(_Plan.weekly),
          ),
          const SizedBox(width: 8),
          // Annual — featured center card (taller, has save badge)
          _FeaturedPlanCard(
            selected: selected == _Plan.annual,
            onTap: () => onSelect(_Plan.annual),
          ),
          const SizedBox(width: 8),
          // Monthly — side card
          _SidePlanCard(
            label: 'MONTHLY',
            price: '\$4.99',
            perUnit: 'per month',
            selected: selected == _Plan.monthly,
            onTap: () => onSelect(_Plan.monthly),
          ),
        ],
      ),
    );
  }
}

// Annual card — taller with the save badge baked in at the top
class _FeaturedPlanCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _FeaturedPlanCard({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Card body — top margin reserves space for the badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(top: _badgeHeight / 2),
              padding: const EdgeInsets.fromLTRB(8, _badgeHeight / 2 + 12, 8, 16),
              decoration: BoxDecoration(
                color: selected ? _purple : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _purple : const Color(0xFFE0D8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: selected ? 0.28 : 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                      color: selected ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$29.99',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'per year',
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? Colors.white60 : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            // Save badge — centered at the very top of the Stack
            Container(
              height: _badgeHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _saveBadge,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Save 81%',
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

// Weekly / Monthly side cards
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _purple : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _purple : const Color(0xFFE0D8F0),
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.25),
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
                  color: selected ? Colors.white70 : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perUnit,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? Colors.white60 : Colors.grey[400],
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

// ── Purchase button ────────────────────────────────────────────────────────────

class _PurchaseButton extends StatelessWidget {
  final _Plan plan;
  final VoidCallback onTap;
  final double bottomPadding;

  const _PurchaseButton({
    required this.plan,
    required this.onTap,
    required this.bottomPadding,
  });

  String get _label => switch (plan) {
        _Plan.weekly => 'Purchase — \$1.99 / week',
        _Plan.annual => 'Purchase — \$29.99 / year',
        _Plan.monthly => 'Purchase — \$4.99 / month',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _purple,
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
        child: Text(_label),
      ),
    );
  }
}
