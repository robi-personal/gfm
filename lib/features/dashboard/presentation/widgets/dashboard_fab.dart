import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/design.dart';

class DashboardFab extends StatelessWidget {
  final GlobalKey<ExpandableFabState> fabKey;
  final bool isCreating;
  final VoidCallback? onAiBuilder;
  final VoidCallback? onCreateForm;
  final VoidCallback? onImport;

  const DashboardFab({
    super.key,
    required this.fabKey,
    required this.isCreating,
    this.onAiBuilder,
    this.onCreateForm,
    this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return ExpandableFab(
      key: fabKey,
      type: ExpandableFabType.up,
      distance: 75,
      duration: const Duration(milliseconds: 220),
      overlayStyle: ExpandableFabOverlayStyle(
        color: const Color(0xFF141028).withValues(alpha: 0.35),
        blur: 3.0,
      ),
      openButtonBuilder: RotateFloatingActionButtonBuilder(
        child: isCreating
            ? const CupertinoActivityIndicator(
                radius: 10, color: Colors.white)
            : const Icon(Icons.add_rounded, size: 26),
        fabSize: ExpandableFabSize.regular,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.purple,
        shape: const CircleBorder(),
      ),
      closeButtonBuilder: DefaultFloatingActionButtonBuilder(
        child: const Icon(Icons.close_rounded, size: 22),
        fabSize: ExpandableFabSize.regular,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.purple,
        shape: const CircleBorder(),
      ),
      children: [
        _FabAction(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Form Builder',
          color: AppColors.purpleAccent,
          lottieAsset: 'assets/lottie/aiFormBuilder.json',
          onTap: isCreating
              ? null
              : () {
                  fabKey.currentState?.toggle();
                  onAiBuilder?.call();
                },
        ),
        _FabAction(
          icon: Icons.edit_note_rounded,
          label: 'Create Form',
          color: AppColors.purple,
          lottieAsset: 'assets/lottie/createForm.json',
          lottieSize: 75,
          onTap: isCreating
              ? null
              : () {
                  fabKey.currentState?.toggle();
                  onCreateForm?.call();
                },
        ),
        _FabAction(
          icon: CupertinoIcons.link,
          label: 'Import Form',
          color: AppColors.purple,
          onTap: isCreating
              ? null
              : () {
                  fabKey.currentState?.toggle();
                  onImport?.call();
                },
        ),
      ],
    );
  }
}

// ── FAB action row (label pill + icon button) ─────────────────────────────────

class _FabAction extends StatelessWidget {
  static const _buttonSize = 52.0;

  final IconData icon;
  final String label;
  final Color color;
  final String? lottieAsset;
  final double? lottieSize;
  final VoidCallback? onTap;

  const _FabAction({
    required this.icon,
    required this.label,
    required this.color,
    this.lottieAsset,
    this.lottieSize,
    this.onTap,
  });

  static Future<LottieComposition?> _dotLottieDecoder(List<int> bytes) {
    return LottieComposition.decodeZip(
      bytes,
      filePicker: (files) => files.firstWhere(
        (f) =>
            f.name.startsWith('animations/') && f.name.endsWith('.json'),
        orElse: () => files.first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDotLottie = lottieAsset?.endsWith('.lottie') ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: lottieAsset != null
                  ? OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Lottie.asset(
                        lottieAsset!,
                        width: lottieSize ?? _buttonSize,
                        height: lottieSize ?? _buttonSize,
                        fit: BoxFit.contain,
                        repeat: true,
                        decoder: isDotLottie ? _dotLottieDecoder : null,
                        errorBuilder: (ctx, e, _) =>
                            Icon(icon, size: 28, color: color),
                      ),
                    )
                  : Icon(icon, size: 28, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
