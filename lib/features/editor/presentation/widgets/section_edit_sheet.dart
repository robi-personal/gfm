import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../pages/tabs/questions/cubit/questions_cubit.dart';

class SectionEditSheet extends StatefulWidget {
  final Item item;

  const SectionEditSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, Item item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<QuestionsCubit>(),
        child: SectionEditSheet(item: item),
      ),
    );
  }

  @override
  State<SectionEditSheet> createState() => _SectionEditSheetState();
}

class _SectionEditSheetState extends State<SectionEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title ?? '');
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final updatedItem = widget.item.copyWith(
      title: _titleCtrl.text.isEmpty ? 'Section' : _titleCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
    );
    context.read<QuestionsCubit>().updateItemFull(updatedItem);
    Navigator.of(context).pop();
  }

  static InputDecoration _inputDec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black45, fontSize: 13),
        filled: true,
        fillColor: AppColors.purpleTintDeep,
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
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets + safeArea),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildHeader(),
          const Divider(height: 1, color: AppColors.borderSubtle),
          _buildFields(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Edit section',
                style: AppTextStyles.screenHeader.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            FilledButton(
              onPressed: _commit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _buildFields() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w500, color: Colors.black87),
              decoration: _inputDec('Section title'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: AppTextStyles.body.copyWith(color: Colors.black87),
              decoration: _inputDec('Description (optional)'),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
      );
}
