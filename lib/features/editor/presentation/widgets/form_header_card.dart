import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              focusNode: _titleFocus,
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: 'Form title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              focusNode: _descFocus,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              decoration: InputDecoration(
                hintText: 'Form description (optional)',
                hintStyle: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outlineVariant),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: theme.colorScheme.onSurfaceVariant),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
