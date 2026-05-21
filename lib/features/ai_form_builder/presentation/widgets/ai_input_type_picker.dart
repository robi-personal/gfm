import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';
import '../cubit/ai_form_builder_cubit.dart';

class AiInputTypePicker extends StatefulWidget {
  final AiInputType selected;
  final bool enabled;
  final bool isPremium;
  final ValueChanged<AiInputType> onChanged;
  final VoidCallback onLockedTap;

  const AiInputTypePicker({
    super.key,
    required this.selected,
    required this.enabled,
    required this.isPremium,
    required this.onChanged,
    required this.onLockedTap,
  });

  @override
  State<AiInputTypePicker> createState() => _AiInputTypePickerState();
}

class _AiInputTypePickerState extends State<AiInputTypePicker> {
  static const _items = <(AiInputType, String, IconData)>[
    (AiInputType.pdf,     'PDF',     CupertinoIcons.doc_text),
    (AiInputType.youtube, 'YouTube', CupertinoIcons.play_rectangle),
    (AiInputType.text,    'Text',    CupertinoIcons.text_alignleft),
    (AiInputType.urls,    'URLs',    CupertinoIcons.link),
    (AiInputType.book,    'Book',    CupertinoIcons.book),
  ];

  final _scrollController = ScrollController();
  final _scrollKey = GlobalKey();
  final _itemKeys = <AiInputType, GlobalKey>{
    AiInputType.pdf:     GlobalKey(),
    AiInputType.youtube: GlobalKey(),
    AiInputType.text:    GlobalKey(),
    AiInputType.urls:    GlobalKey(),
    AiInputType.book:    GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(AiInputTypePicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final itemKey = _itemKeys[widget.selected];
    if (itemKey == null) return;
    final itemCtx = itemKey.currentContext;
    final scrollCtx = _scrollKey.currentContext;
    if (itemCtx == null || scrollCtx == null) return;

    final itemBox   = itemCtx.findRenderObject()   as RenderBox;
    final scrollBox = scrollCtx.findRenderObject() as RenderBox;

    final itemGlobalX   = itemBox.localToGlobal(Offset.zero).dx;
    final scrollGlobalX = scrollBox.localToGlobal(Offset.zero).dx;

    final itemOffsetInContent = (itemGlobalX - scrollGlobalX) + _scrollController.offset;
    final targetOffset = itemOffsetInContent + itemBox.size.width / 2 - scrollBox.size.width / 2;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _scrollKey,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShapes.cardShadow,
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (type, label, icon) in _items)
              _TypeChip(
                key: _itemKeys[type],
                label: label,
                icon: icon,
                selected: widget.selected == type,
                enabled: widget.enabled,
                locked: !widget.isPremium && type != AiInputType.text,
                onTap: () => widget.onChanged(type),
                onLockedTap: widget.onLockedTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onLockedTap;

  const _TypeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onLockedTap,
    this.locked = false,
  });

  static const _disabled = AppColors.muted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? onLockedTap : (enabled ? onTap : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected && !locked ? AppColors.purple600 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: locked ? _disabled : (selected ? Colors.white : _disabled),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: locked ? _disabled : (selected ? Colors.white : AppColors.ink2),
              ),
            ),
            if (locked) ...[
              const SizedBox(width: 4),
              const Icon(Icons.workspace_premium, size: 11, color: _disabled),
            ],
          ],
        ),
      ),
    );
  }
}
