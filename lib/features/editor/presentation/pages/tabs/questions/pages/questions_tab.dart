import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../../core/models/item_content.dart';
import '../../../../../../../core/widgets/error_modal.dart';
import '../../../../cubit/editor_cubit.dart';
import '../../../../widgets/editor_body.dart';
import '../../../../widgets/question_edit_sheet.dart';
import '../../../../widgets/text_block_edit_sheet.dart';
import '../../../edit_form_webview_page.dart';
import '../widgets/file_upload_info_dialog.dart';
import '../widgets/questions_bottom_bar.dart';

class QuestionsTab extends StatelessWidget {
  final String formId;

  const QuestionsTab({super.key, required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorCubit, EditorState>(
      listenWhen: (prev, curr) {
        if (curr is! EditorLoaded) return false;
        final p = prev is EditorLoaded ? prev : null;
        if (curr.pendingEditItemId != null &&
            curr.pendingEditItemId != p?.pendingEditItemId) return true;
        if (curr.fileUploadViaWebRequested && !(p?.fileUploadViaWebRequested ?? false)) {
          return true;
        }
        if (curr.fileUploadEditViaWebRequested &&
            !(p?.fileUploadEditViaWebRequested ?? false)) return true;
        return false;
      },
      listener: _onStateChange,
      child: Stack(
        children: [
          const EditorBody(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BlocSelector<EditorCubit, EditorState, bool>(
              selector: (s) => s is EditorLoaded && !s.isSaving,
              builder: (context, enabled) =>
                  QuestionsBottomBar(enabled: enabled, formId: formId),
            ),
          ),
        ],
      ),
    );
  }

  void _onStateChange(BuildContext context, EditorState state) {
    if (state case EditorLoaded(:final pendingEditItemId?)) {
      final cubit = context.read<EditorCubit>();
      cubit.clearPendingEdit();
      final item = state.form.items
          .where((i) => i.itemId == pendingEditItemId)
          .firstOrNull;
      if (item != null) {
        if (item.content is TextItemContent) {
          TextBlockEditSheet.show(context, item);
        } else {
          final sections = state.form.items
              .where((i) => i.content is PageBreakItemContent)
              .toList();
          QuestionEditSheet.show(
            context,
            item,
            sections,
            isQuiz: state.form.settings.quizSettings.isQuiz,
          );
        }
      }
      return;
    }

    if (state case EditorLoaded(fileUploadViaWebRequested: true)) {
      context.read<EditorCubit>().clearFileUploadRequest();
      _runFileUploadWebFlow(context, isEditing: false);
    }

    if (state case EditorLoaded(fileUploadEditViaWebRequested: true)) {
      context.read<EditorCubit>().clearEditFileUploadRequest();
      _runFileUploadWebFlow(context, isEditing: true);
    }
  }

  Future<void> _runFileUploadWebFlow(
    BuildContext context, {
    required bool isEditing,
  }) async {
    if (isEditing) {
      final proceed = await showFileUploadInfoDialog(context, isEditing: true);
      if (proceed != true || !context.mounted) return;
    }

    final cubit = context.read<EditorCubit>();
    final state = cubit.state;
    if (state is! EditorLoaded) return;

    if (state.isDirty) {
      bool saveAndContinue = false;
      await ErrorModal.show(
        context,
        title: 'Save your changes first?',
        body: 'You have unsaved edits. We need to save them before opening '
            'the web editor — otherwise they will be lost.',
        primaryLabel: 'Save & continue',
        onPrimary: () => saveAndContinue = true,
        secondaryLabel: 'Cancel',
        onSecondary: () {},
      );
      if (!saveAndContinue || !context.mounted) return;
      await cubit.save();
      if (!context.mounted) return;
      final after = cubit.state;
      if (after is EditorLoaded && (after.isDirty || after.saveFailed)) return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditFormWebViewPage(
          formId: formId,
          title: isEditing ? 'Edit file upload' : 'Add file upload',
        ),
      ),
    );
    if (!context.mounted) return;
    await context.read<EditorCubit>().refreshFromServer();
  }
}
