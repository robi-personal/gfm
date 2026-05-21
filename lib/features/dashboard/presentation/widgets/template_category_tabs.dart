import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/design.dart';

// ── Tab definitions ───────────────────────────────────────────────────────────

const _kTabDefs = [
  ('All',       null),
  ('Work',      CupertinoIcons.briefcase),
  ('Personal',  CupertinoIcons.person),
  ('Education', CupertinoIcons.book),
];

// ── Category tab bar ──────────────────────────────────────────────────────────

class TemplateCategoryTabBar extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const TemplateCategoryTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<TemplateCategoryTabBar> createState() => _TemplateCategoryTabBarState();
}

class _TemplateCategoryTabBarState extends State<TemplateCategoryTabBar> {
  final _keys = List.generate(_kTabDefs.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(TemplateCategoryTabBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _scrollToSelected();
  }

  void _scrollToSelected() {
    final idx = _kTabDefs.indexWhere((t) => t.$1 == widget.selected);
    if (idx == -1) return;
    final ctx = _keys[idx].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShapes.cardShadow,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < _kTabDefs.length; i++)
              _TabChip(
                key: _keys[i],
                label: _kTabDefs[i].$1,
                icon: _kTabDefs[i].$2,
                selected: widget.selected == _kTabDefs[i].$1,
                onTap: () => widget.onSelected(_kTabDefs[i].$1),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tab chip ──────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple600 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
