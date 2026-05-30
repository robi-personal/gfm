import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/design.dart';
import '../../../../../core/utils/layout.dart';
import '../../domain/entities/form_entry.dart';
import '../cubit/dashboard_cubit.dart';
import 'dashboard_form_card.dart';

class DashboardFormList extends StatelessWidget {
  final List<FormEntry> forms;
  final String query;
  final SortOrder sortOrder;
  final String? renamingId;

  const DashboardFormList({
    super.key,
    required this.forms,
    required this.query,
    required this.sortOrder,
    this.renamingId,
  });

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) return const SizedBox.shrink();

    final bottomPad = MediaQuery.viewPaddingOf(context).bottom + 90;
    final tablet = isTablet(context);
    final items = _buildItems(forms, renamingId, sortOrder);

    return RefreshIndicator(
      color: AppColors.purple600,
      onRefresh: () => context.read<DashboardCubit>().refresh(),
      child: tablet
          ? _tabletGrid(context, bottomPad)
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return switch (item) {
                  _SectionHeader(:final label) =>
                    _SectionLabel(label: label),
                  _FormItem(:final form, :final isRenaming) =>
                    DashboardFormCard(form: form, isRenaming: isRenaming),
                };
              },
            ),
    );
  }

  Widget _tabletGrid(BuildContext context, double bottomPad) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 0,
        mainAxisExtent: 90,
      ),
      itemCount: forms.length,
      itemBuilder: (_, i) => DashboardFormCard(
        form: forms[i],
        isRenaming: forms[i].id == renamingId,
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        label,
        style: AppTextStyles.sectionLabel,
      ),
    );
  }
}

// ── Grouping logic ────────────────────────────────────────────────────────────

sealed class _ListItem {}

class _SectionHeader extends _ListItem {
  final String label;
  _SectionHeader(this.label);
}

class _FormItem extends _ListItem {
  final FormEntry form;
  final bool isRenaming;
  _FormItem(this.form, {this.isRenaming = false});
}

List<_ListItem> _buildItems(List<FormEntry> forms, String? renamingId, SortOrder sortOrder) {
  final now = DateTime.now();
  final today = <FormEntry>[];
  final thisWeek = <FormEntry>[];
  final earlier = <FormEntry>[];

  for (final f in forms) {
    final t = sortOrder == SortOrder.modifiedDesc ? f.modifiedTime : f.createdTime;
    if (t == null) {
      earlier.add(f);
      continue;
    }
    final isToday = t.year == now.year &&
        t.month == now.month &&
        t.day == now.day;
    if (isToday) {
      today.add(f);
    } else if (now.difference(t).inDays < 7) {
      thisWeek.add(f);
    } else {
      earlier.add(f);
    }
  }

  return [
    if (today.isNotEmpty) ...[
      _SectionHeader('TODAY'),
      ...today.map((f) =>
          _FormItem(f, isRenaming: f.id == renamingId)),
    ],
    if (thisWeek.isNotEmpty) ...[
      _SectionHeader('THIS WEEK'),
      ...thisWeek.map((f) =>
          _FormItem(f, isRenaming: f.id == renamingId)),
    ],
    if (earlier.isNotEmpty) ...[
      _SectionHeader('EARLIER'),
      ...earlier.map((f) =>
          _FormItem(f, isRenaming: f.id == renamingId)),
    ],
  ];
}
