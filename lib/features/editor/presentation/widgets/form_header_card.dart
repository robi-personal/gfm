import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubit/editor_cubit.dart';

/// Editable form title and description at the top of the editor.
/// Pushes to the cubit only on focus-lost (not on every keystroke).
class FormHeaderCard extends StatefulWidget {
  final String initialTitle;
  final String? initialDescription;

  const FormHeaderCard({
    super.key,
    required this.initialTitle,
    this.initialDescription,
  });

  @override
  State<FormHeaderCard> createState() => _FormHeaderCardState();
}

class _FormHeaderCardState extends State<FormHeaderCard> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final FocusNode _titleFocus;
  late final FocusNode _descFocus;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription ?? '');

    _titleFocus = FocusNode()
      ..addListener(() {
        if (!_titleFocus.hasFocus) {
          context.read<EditorCubit>().updateTitle(_titleCtrl.text);
        }
      });

    _descFocus = FocusNode()
      ..addListener(() {
        if (!_descFocus.hasFocus) {
          context.read<EditorCubit>().updateDescription(_descCtrl.text);
        }
      });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Purple left accent — thicker to distinguish header
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      focusNode: _titleFocus,
                      style: AppTextStyles.screenHeader,
                      decoration: InputDecoration(
                        hintText: 'Form title',
                        hintStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAEAEB2),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.purple, width: 1.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      focusNode: _descFocus,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Form description (optional)',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFAEAEB2),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: AppColors.textSecondary, width: 1),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
