import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/design.dart';
import '../../../../../core/widgets/error_modal.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import 'dashboard_dialogs.dart';
import 'form_clipboard_thumb.dart';

class DashboardFormCard extends StatelessWidget {
  final FormEntry form;
  final bool isRenaming;

  const DashboardFormCard({
    super.key,
    required this.form,
    this.isRenaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppShapes.cardRadius2,
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShapes.cardShadow,
      ),
      child: InkWell(
        onTap: () => _openForm(context),
        borderRadius: AppShapes.cardRadius2,
        splashColor: AppColors.purple600.withValues(alpha: 0.06),
        highlightColor: AppColors.purple600.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              FormClipboardThumb(
                variant: form.isOwned
                    ? FormThumbVariant.regular
                    : FormThumbVariant.imported,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(child: _FormMeta(form: form)),
              const SizedBox(width: 8),
              isRenaming
                  ? const CupertinoActivityIndicator(
                      radius: 10, color: AppColors.purple600)
                  : _KebabMenu(form: form),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorPage(formId: form.id, formName: form.name),
    ));
  }
}

// ── Meta column ───────────────────────────────────────────────────────────────

class _FormMeta extends StatelessWidget {
  final FormEntry form;

  const _FormMeta({required this.form});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          form.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.cardTitle,
        ),
        if (form.modifiedTime != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(CupertinoIcons.clock,
                  size: 12, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                _relativeDate(form.modifiedTime!),
                style: AppTextStyles.meta,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return 'Today, $h:$m $period';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Kebab menu ────────────────────────────────────────────────────────────────

enum _RowAction { open, rename, delete, removeImport }

class _KebabMenu extends StatelessWidget {
  final FormEntry form;

  const _KebabMenu({required this.form});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RowAction>(
      onSelected: (a) => _handleAction(context, a),
      icon: const Icon(CupertinoIcons.ellipsis,
          color: AppColors.muted, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _menuItem(_RowAction.open, CupertinoIcons.arrow_up_right_square,
            'Open', AppColors.ink2),
        if (form.isOwned)
          _menuItem(_RowAction.rename, CupertinoIcons.pencil,
              'Rename', AppColors.ink2),
        if (form.isOwned)
          _menuItem(_RowAction.delete, CupertinoIcons.trash,
              'Delete', AppColors.error)
        else
          _menuItem(_RowAction.removeImport, CupertinoIcons.minus_circle,
              'Remove from list', AppColors.error),
      ],
    );
  }

  PopupMenuItem<_RowAction> _menuItem(
      _RowAction action, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: action,
      child: Row(
        spacing: 10,
        children: [
          Icon(icon, size: 16, color: color),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, _RowAction action) {
    switch (action) {
      case _RowAction.open:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              EditorPage(formId: form.id, formName: form.name),
        ));
      case _RowAction.rename:
        _rename(context);
      case _RowAction.delete:
        _confirmDelete(context);
      case _RowAction.removeImport:
        _removeImport(context);
    }
  }

  void _rename(BuildContext context) async {
    final cubit = context.read<DashboardCubit>();
    final name = await showRenameDialog(context, current: form.name);
    if (name == null || !context.mounted) return;
    try {
      await cubit.renameForm(form.id, name);
    } catch (_) {
      if (!context.mounted) return;
      ErrorModal.show(
        context,
        title: "Couldn't rename form.",
        body: 'Check your connection and try again.',
        secondaryLabel: 'Cancel',
        onSecondary: () {},
        primaryLabel: 'Retry',
        onPrimary: () => _rename(context),
      );
    }
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmSheet(context);
    if (confirmed != true || !context.mounted) return;
    final cubit = context.read<DashboardCubit>();
    try {
      await cubit.deleteForm(form.id);
    } catch (_) {
      if (context.mounted) {
        ErrorModal.show(
          context,
          title: "Couldn't delete this form.",
          body: "It's still in your list.",
          secondaryLabel: 'Cancel',
          onSecondary: () {},
          primaryLabel: 'Retry',
          onPrimary: () => cubit.deleteForm(form.id),
        );
      }
    }
  }

  void _removeImport(BuildContext context) async {
    final confirmed =
        await showRemoveImportSheet(context, formName: form.name);
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<DashboardCubit>().removeImportedForm(form.id);
    } catch (_) {
      if (context.mounted) {
        ErrorModal.show(
          context,
          title: "Couldn't remove form.",
          body: 'Check your connection and try again.',
          secondaryLabel: 'Cancel',
          onSecondary: () {},
          primaryLabel: 'Retry',
          onPrimary: () => _removeImport(context),
        );
      }
    }
  }
}
