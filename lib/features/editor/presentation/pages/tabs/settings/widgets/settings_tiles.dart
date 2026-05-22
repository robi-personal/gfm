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

/// Small uppercase label that sits inside a SettingsCard to delineate a
/// sub-section (e.g. "REQUIRES SIGN IN" under the Responses group). Mirrors
/// Google Forms' web settings grouping. SizedBox forces full width so the
/// label left-aligns inside the parent Column (which defaults to center).
class SettingsSubHeader extends StatelessWidget {
  final String label;

  const SettingsSubHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          label,
          textAlign: TextAlign.left,
          style: AppTextStyles.meta.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.purple,
          ),
        ),
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

class SettingsOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const SettingsOption({required this.value, required this.label, this.subtitle});
}

/// A single-line settings row that opens a bottom-sheet picker on tap.
/// The trailing text shows the current selection's short label; a chevron
/// hints that tapping reveals more options. Pattern: Google web Forms
/// "Collect email addresses [Do not collect ▼]".
class SettingsDropdownTile<T> extends StatelessWidget {
  final String label;
  final String? subtitle;
  final T value;
  final String valueLabel;
  final List<SettingsOption<T>> options;
  final ValueChanged<T>? onChanged;
  final bool isLast;

  const SettingsDropdownTile({
    super.key,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.options,
    this.subtitle,
    this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Column(
      children: [
        InkWell(
          onTap: enabled ? () => _openPicker(context) : null,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.body.copyWith(fontSize: 15)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTextStyles.meta),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  valueLabel,
                  style: AppTextStyles.meta.copyWith(
                    color: enabled ? AppColors.purple : AppColors.muted2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 14,
                  color: enabled ? AppColors.purple : AppColors.muted2,
                ),
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

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
      builder: (_) => _OptionPickerSheet<T>(
        title: label,
        currentValue: value,
        options: options,
      ),
    );
    if (picked != null && picked != value) onChanged!(picked);
  }
}

class _OptionPickerSheet<T> extends StatelessWidget {
  final String title;
  final T currentValue;
  final List<SettingsOption<T>> options;

  const _OptionPickerSheet({
    required this.title,
    required this.currentValue,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 16;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29141028),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E1EB),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          for (var i = 0; i < options.length; i++)
            _OptionRow<T>(
              option: options[i],
              isSelected: options[i].value == currentValue,
              isLast: i == options.length - 1,
              onTap: () => Navigator.of(context).pop(options[i].value),
            ),
        ],
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  final SettingsOption<T> option;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? AppColors.purple : AppColors.ink,
                        ),
                      ),
                      if (option.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(option.subtitle!, style: AppTextStyles.meta),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(CupertinoIcons.checkmark, size: 18, color: AppColors.purple),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 24),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}

class SettingsActionTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final bool isLast;
  final VoidCallback? onTap;

  const SettingsActionTile({
    super.key,
    this.icon,
    required this.label,
    this.subtitle,
    this.subtitleStyle,
    this.trailing,
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
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.purple),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.body.copyWith(fontSize: 15)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle ?? AppTextStyles.meta,
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 48 : 16),
            child: const Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}

/// Bottom-sheet text editor — returns the new value on Save, or null if the
/// user dismisses. Multi-line input, with a Save button that's disabled until
/// the value differs from [initial].
Future<String?> showSettingsTextEdit(
  BuildContext context, {
  required String title,
  required String initial,
  String? hint,
  int? maxLength,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
    builder: (_) => _TextEditSheet(
      title: title,
      initial: initial,
      hint: hint,
      maxLength: maxLength,
    ),
  );
}

class _TextEditSheet extends StatefulWidget {
  final String title;
  final String initial;
  final String? hint;
  final int? maxLength;

  const _TextEditSheet({
    required this.title,
    required this.initial,
    this.hint,
    this.maxLength,
  });

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _controller;
  late String _value;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _value = widget.initial;
    _controller.addListener(() {
      if (_controller.text != _value) {
        setState(() => _value = _controller.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom +
        20;
    final dirty = _value != widget.initial && _value.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x29141028),
              blurRadius: 30,
              offset: Offset(0, -10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E1EB),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 3,
              maxLength: widget.maxLength,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: dirty ? () => Navigator.of(context).pop(_value) : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dirty ? AppColors.purple : AppColors.iconInactive,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
