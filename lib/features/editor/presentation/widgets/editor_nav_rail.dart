import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class EditorNavRail extends StatefulWidget {
  final TabController controller;
  final int? responseCount;

  const EditorNavRail({
    super.key,
    required this.controller,
    this.responseCount,
  });

  @override
  State<EditorNavRail> createState() => _EditorNavRailState();
}

class _EditorNavRailState extends State<EditorNavRail> {
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
    final hasResponses =
        widget.responseCount != null && widget.responseCount! > 0;

    return NavigationRail(
      selectedIndex: selected,
      onDestinationSelected: (i) => widget.controller.animateTo(i),
      labelType: NavigationRailLabelType.all,
      backgroundColor: AppColors.purpleDark,
      indicatorColor: Colors.white.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme:
          IconThemeData(color: Colors.white.withValues(alpha: 0.50)),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.50),
        fontSize: 11,
      ),
      destinations: [
        const NavigationRailDestination(
          icon: Icon(CupertinoIcons.list_bullet),
          label: Text('Questions'),
        ),
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: hasResponses,
            label: Text('${widget.responseCount}'),
            backgroundColor: Colors.white.withValues(alpha: 0.30),
            textColor: Colors.white,
            child: const Icon(CupertinoIcons.chart_bar_alt_fill),
          ),
          label: const Text('Responses'),
        ),
        const NavigationRailDestination(
          icon: Icon(CupertinoIcons.settings_solid),
          label: Text('Settings'),
        ),
      ],
    );
  }
}
