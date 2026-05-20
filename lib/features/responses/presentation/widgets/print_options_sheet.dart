import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/form_response.dart';
import '../../../../core/theme/app_colors.dart';

/// One of the four print formats the user can pick in the first bottom sheet.
enum PrintFormat { table, questionnaire, summary, individual }

/// Shows the first bottom sheet with the 4 format options + Continue.
/// Returns the chosen format, or null if dismissed.
Future<PrintFormat?> showPrintOptionsSheet(BuildContext context) {
  return showModalBottomSheet<PrintFormat>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _PrintOptionsSheet(),
  );
}

class _PrintOptionsSheet extends StatefulWidget {
  const _PrintOptionsSheet();

  @override
  State<_PrintOptionsSheet> createState() => _PrintOptionsSheetState();
}

class _PrintOptionsSheetState extends State<_PrintOptionsSheet> {
  PrintFormat _selected = PrintFormat.questionnaire;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Print',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FormatTile(
                        icon: CupertinoIcons.doc_text,
                        label: 'Questionnaire',
                        selected: _selected == PrintFormat.questionnaire,
                        onTap: () => setState(
                            () => _selected = PrintFormat.questionnaire),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormatTile(
                        icon: CupertinoIcons.square_grid_2x2,
                        label: 'Table',
                        selected: _selected == PrintFormat.table,
                        onTap: () =>
                            setState(() => _selected = PrintFormat.table),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FormatTile(
                        icon: CupertinoIcons.chart_bar_alt_fill,
                        label: 'Summary',
                        selected: _selected == PrintFormat.summary,
                        onTap: () =>
                            setState(() => _selected = PrintFormat.summary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FormatTile(
                        icon: CupertinoIcons.person_2,
                        label: 'Individual',
                        selected: _selected == PrintFormat.individual,
                        onTap: () => setState(
                            () => _selected = PrintFormat.individual),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.purple,
                pressedOpacity: 0.85,
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.purple : AppColors.groupedBackground;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? null
              : Border.all(color: const Color(0xFFE5E5EA), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: fg),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual selection sheet ───────────────────────────────────────────────

/// Second bottom sheet shown when the user picks "Individual". Returns the
/// list of selected responses (or null if dismissed). Caller is responsible
/// for generating + printing the PDF.
Future<List<FormResponse>?> showIndividualPickerSheet(
  BuildContext context, {
  required List<FormResponse> allResponses,
}) {
  return showModalBottomSheet<List<FormResponse>>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    isDismissible: false, // explicit close button only
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _IndividualPickerSheet(allResponses: allResponses),
  );
}

class _IndividualPickerSheet extends StatefulWidget {
  final List<FormResponse> allResponses;

  const _IndividualPickerSheet({required this.allResponses});

  @override
  State<_IndividualPickerSheet> createState() => _IndividualPickerSheetState();
}

class _IndividualPickerSheetState extends State<_IndividualPickerSheet> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FormResponse> get _filtered {
    if (_query.isEmpty) return widget.allResponses;
    return widget.allResponses
        .where((r) => (r.respondentEmail ?? '').toLowerCase().contains(_query))
        .toList();
  }

  bool get _allFilteredSelected {
    final filtered = _filtered;
    if (filtered.isEmpty) return false;
    return filtered.every((r) => _selectedIds.contains(r.responseId));
  }

  void _toggleSelectAll() {
    setState(() {
      final filtered = _filtered;
      if (_allFilteredSelected) {
        for (final r in filtered) {
          _selectedIds.remove(r.responseId);
        }
      } else {
        for (final r in filtered) {
          _selectedIds.add(r.responseId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.of(context).size.height;
    final maxHeight = viewportHeight * 0.85;
    final filtered = _filtered;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select responses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary),
                cursorColor: AppColors.purple,
                decoration: InputDecoration(
                  hintText: 'Search by email…',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  filled: true,
                  fillColor: AppColors.groupedBackground,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.purple, width: 1.5),
                  ),
                ),
              ),
            ),

            // Select all
            InkWell(
              onTap: filtered.isEmpty ? null : _toggleSelectAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    _CheckBox(checked: _allFilteredSelected),
                    const SizedBox(width: 12),
                    Text(
                      _allFilteredSelected ? 'Deselect all' : 'Select all',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.separator),

            // List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No respondents match.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final id = r.responseId;
                        final checked = _selectedIds.contains(id);
                        return _RespondentRow(
                          email: (r.respondentEmail ?? '').isEmpty
                              ? 'Anonymous'
                              : r.respondentEmail!,
                          timestamp: _formatTimestamp(r.createTime.toLocal()),
                          checked: checked,
                          onTap: () => setState(() {
                            if (checked) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          }),
                        );
                      },
                    ),
            ),

            // Footer: Print N selected
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.viewPaddingOf(context).bottom + 14,
              ),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final picked = widget.allResponses
                              .where((r) => _selectedIds.contains(r.responseId))
                              .toList();
                          Navigator.of(context).pop(picked);
                        },
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.purple,
                  disabledColor: AppColors.iconInactive,
                  pressedOpacity: 0.85,
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Print'
                        : 'Print ${_selectedIds.length} selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RespondentRow extends StatelessWidget {
  final String email;
  final String timestamp;
  final bool checked;
  final VoidCallback onTap;

  const _RespondentRow({
    required this.email,
    required this.timestamp,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = _initial(email);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: checked ? AppColors.purpleTint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? AppColors.purple : const Color(0xFFE5E5EA),
            width: checked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.purpleTint,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purple,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CheckBox(checked: checked),
          ],
        ),
      ),
    );
  }

  static String _initial(String email) {
    if (email.isEmpty) return '?';
    final ch = email.trim()[0].toUpperCase();
    return RegExp(r'[A-Z0-9]').hasMatch(ch) ? ch : '?';
  }
}

class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.purple : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? AppColors.purple : const Color(0xFFC7C7CC),
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(CupertinoIcons.check_mark, size: 14, color: Colors.white)
          : null,
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatTimestamp(DateTime dt) {
  final m = _months[dt.month - 1];
  final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$m ${dt.day}, ${dt.year} · $hour12:$mm $ampm';
}
