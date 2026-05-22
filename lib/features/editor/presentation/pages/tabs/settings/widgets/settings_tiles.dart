import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

class SettingsGroupLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const SettingsGroupLabel({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.meta.copyWith(letterSpacing: 0.4),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class SettingsRadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isLast;
  final VoidCallback? onTap;

  const SettingsRadioTile({
    super.key,
    required this.label,
    required this.selected,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                  ),
                ),
                if (selected)
                  const Icon(CupertinoIcons.checkmark, size: 18, color: AppColors.purple),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool isLast;
  final bool isLoading;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.isLast = false,
    this.isLoading = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(fontSize: 15),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.meta),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 51,
                  child: Center(
                    child: CupertinoActivityIndicator(radius: 10, color: AppColors.purple),
                  ),
                )
              else
                CupertinoSwitch(
                  value: value,
                  activeTrackColor: AppColors.purple,
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}

class SettingsActionTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Widget? trailing;
  final bool isLast;
  final VoidCallback? onTap;

  const SettingsActionTile({
    super.key,
    this.icon,
    required this.label,
    this.trailing,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leading = icon != null
        ? Icon(icon, size: 20, color: AppColors.purple)
        : const SizedBox(width: 20);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 48),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}
