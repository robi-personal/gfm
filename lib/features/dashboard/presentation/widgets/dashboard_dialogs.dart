import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

// ── Import info sheet ─────────────────────────────────────────────────────────

Future<bool?> showImportInfoDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
    builder: (_) => const _ImportInfoSheet(),
  );
}

class _ImportInfoSheet extends StatelessWidget {
  const _ImportInfoSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 28;

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
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildBodyCopy(),
          const SizedBox(height: 16),
          _buildPrivacyCard(),
          const SizedBox(height: 20),
          _buildPrimaryButton(context),
          const SizedBox(height: 4),
          _buildTertiaryButton(context),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 5,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E1EB),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );

  Widget _buildHeader() => Row(
        spacing: 14,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.purple50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.info_circle,
                color: AppColors.purple600, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Heads up',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.ink,
                ),
              ),
              Text(
                'Privacy & scope',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildBodyCopy() => const Text(
        'For your privacy, GFM only sees forms it created here. '
        'Forms you made on the Google Forms website or in other apps '
        'won\'t show up automatically — tap below to browse your Drive '
        'and pick the ones to import.',
        style: TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.ink2),
      );

  Widget _buildPrivacyCard() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.purple50,
          border: Border.all(color: AppColors.purple100),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          spacing: 10,
          children: [
            _BulletRow(text: 'Only see forms you select'),
            _BulletRow(text: 'Revoke access anytime in Settings'),
          ],
        ),
      );

  Widget _buildPrimaryButton(BuildContext context) => PrimaryButton(
        label: 'Import Existing Forms',
        onTap: () => Navigator.of(context).pop(true),
      );

  Widget _buildTertiaryButton(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 44,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(false),
          behavior: HitTestBehavior.opaque,
          child: const Center(
            child: Text(
              'Maybe later',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      );
}

class _BulletRow extends StatelessWidget {
  final String text;

  const _BulletRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: AppColors.purple600,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 9, color: Colors.white),
        ),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.purple600,
          ),
        ),
      ],
    );
  }
}

// ── Rename sheet ──────────────────────────────────────────────────────────────

Future<String?> showRenameDialog(BuildContext context,
    {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
    builder: (_) => _RenameSheet(current: current),
  );
}

class _RenameSheet extends StatefulWidget {
  final String current;

  const _RenameSheet({required this.current});

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current)
      ..selection =
          TextSelection(baseOffset: 0, extentOffset: widget.current.length);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (_canSave) Navigator.of(context).pop(_controller.text.trim());
  }

  void _cancel() => Navigator.of(context).pop(null);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom +
        28;

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
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTextField(),
          const SizedBox(height: 20),
          _buildActions(),
          const SizedBox(height: 4),
          _buildCancelButton(),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 5,
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E1EB),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );

  Widget _buildHeader() => Row(
        spacing: 14,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.purple50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(CupertinoIcons.pencil,
                color: AppColors.purple600, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rename Form',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppColors.ink,
                ),
              ),
              Text(
                'Enter a new name',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildTextField() => TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        cursorColor: AppColors.purple600,
        decoration: InputDecoration(
          hintText: 'Form name',
          hintStyle: const TextStyle(color: AppColors.muted2),
          filled: true,
          fillColor: AppColors.bg,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.purple600, width: 1.5),
          ),
        ),
        onSubmitted: (_) => _submit(),
      );

  Widget _buildActions() => PrimaryButton(
        label: 'Save',
        onTap: _canSave ? _submit : null,
      );

  Widget _buildCancelButton() => SizedBox(
        width: double.infinity,
        height: 44,
        child: GestureDetector(
          onTap: _cancel,
          behavior: HitTestBehavior.opaque,
          child: const Center(
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
      );
}

