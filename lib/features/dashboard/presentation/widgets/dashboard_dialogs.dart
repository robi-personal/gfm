import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';

// ── Import info sheet ─────────────────────────────────────────────────────────

Future<bool?> showImportInfoDialog(BuildContext context) {
  return _showSheet<bool>(context, child: const _ImportInfoSheet());
}

class _ImportInfoSheet extends StatelessWidget {
  const _ImportInfoSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 28;

    return _SheetContainer(
      bottomPad: bottomPad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const _SheetHeader(
            icon: CupertinoIcons.info_circle,
            title: 'Heads up',
            subtitle: 'Privacy & scope',
          ),
          const SizedBox(height: 16),
          _buildBodyCopy(),
          const SizedBox(height: 16),
          _buildPrivacyCard(),
          const SizedBox(height: 20),
          _buildPrimaryButton(context),
          const SizedBox(height: 4),
          _SheetTertiaryButton(
            label: 'Maybe later',
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

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
}

// ── Rename sheet ──────────────────────────────────────────────────────────────

Future<String?> showRenameDialog(BuildContext context,
    {required String current}) {
  return _showSheet<String>(context, child: _RenameSheet(current: current));
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom +
        28;

    return _SheetContainer(
      bottomPad: bottomPad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const _SheetHeader(
            icon: CupertinoIcons.pencil,
            title: 'Rename Form',
            subtitle: 'Enter a new name',
          ),
          const SizedBox(height: 16),
          _buildTextField(),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save',
            onTap: _canSave ? _submit : null,
          ),
          const SizedBox(height: 4),
          _SheetTertiaryButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
    );
  }

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
}

// ── Delete confirm sheet ──────────────────────────────────────────────────────

Future<bool?> showDeleteConfirmSheet(BuildContext context) {
  return _showSheet<bool>(context, child: const _DeleteConfirmSheet());
}

class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 28;

    return _SheetContainer(
      bottomPad: bottomPad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const _SheetHeader(
            icon: CupertinoIcons.trash,
            title: 'Delete this form?',
            subtitle: 'This action cannot be undone',
          ),
          const SizedBox(height: 16),
          _buildBody(),
          const SizedBox(height: 20),
          _buildDeleteButton(context),
          const SizedBox(height: 4),
          _SheetTertiaryButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() => const Text(
        'The form will be moved to trash in your Google Drive.',
        style: TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.ink2),
      );

  Widget _buildDeleteButton(BuildContext context) => _DestructiveButton(
        label: 'Delete',
        onTap: () => Navigator.of(context).pop(true),
      );
}

// ── Remove import sheet ───────────────────────────────────────────────────────

Future<bool?> showRemoveImportSheet(BuildContext context,
    {required String formName}) {
  return _showSheet<bool>(
      context, child: _RemoveImportSheet(formName: formName));
}

class _RemoveImportSheet extends StatelessWidget {
  final String formName;

  const _RemoveImportSheet({required this.formName});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 28;

    return _SheetContainer(
      bottomPad: bottomPad,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const _SheetHeader(
            icon: CupertinoIcons.minus_circle,
            title: 'Remove from list?',
            subtitle: 'The original form won\'t be affected',
          ),
          const SizedBox(height: 16),
          _buildBody(),
          const SizedBox(height: 20),
          _buildRemoveButton(context),
          const SizedBox(height: 4),
          _SheetTertiaryButton(
            label: 'Cancel',
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() => Text(
        '"$formName" will be removed from your imported list.',
        style: const TextStyle(
            fontSize: 14.5, height: 1.55, color: AppColors.ink2),
      );

  Widget _buildRemoveButton(BuildContext context) => _DestructiveButton(
        label: 'Remove',
        onTap: () => Navigator.of(context).pop(true),
      );
}

// ── Shared sheet primitives ───────────────────────────────────────────────────

Future<T?> _showSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF141028).withValues(alpha: 0.45),
    builder: (_) => child,
  );
}

class _SheetContainer extends StatelessWidget {
  final Widget child;
  final double bottomPad;

  const _SheetContainer({required this.child, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
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
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 14,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.purple50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.purple600, size: 20),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.ink,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SheetTertiaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SheetTertiaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DestructiveButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppShapes.buttonRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
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
