import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// iOS-style toggle. ON tint = purple600.
class DsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const DsToggle({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      activeTrackColor: AppColors.purple600,
      onChanged: onChanged,
    );
  }
}
