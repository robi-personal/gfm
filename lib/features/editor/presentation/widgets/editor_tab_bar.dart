import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class EditorSegmentedTabBar extends StatefulWidget {
  final TabController controller;
  final int? responseCount;

  const EditorSegmentedTabBar({
    super.key,
    required this.controller,
    this.responseCount,
  });

  @override
  State<EditorSegmentedTabBar> createState() => _EditorSegmentedTabBarState();
}

class _EditorSegmentedTabBarState extends State<EditorSegmentedTabBar> {
  static const _tabs = [
    (icon: CupertinoIcons.list_bullet, label: 'Questions'),
    (icon: CupertinoIcons.chart_bar_alt_fill, label: 'Responses'),
    (icon: CupertinoIcons.settings_solid, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.purpleDark.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isSelected = i == selected;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.controller.index = i,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _tabs[i].icon,
                                    size: isSelected ? 16 : 15,
                                    color: Colors.white.withValues(alpha: 1.0),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _tabs[i].label,
                                    style: TextStyle(
                                      fontSize: isSelected ? 14 : 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: Colors.white.withValues(alpha: 1.0),
                                    ),
                                  ),
                                  if (i == 1 && widget.responseCount != null && widget.responseCount! > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${widget.responseCount}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: isSelected ? 2.5 : 0,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
