import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../../core/api/drive_client.dart';
import '../../../../../../../core/di/injection.dart';
import '../../../../../../../core/models/item.dart';
import '../../../../../../../core/models/item_content.dart';
import '../../../../../../../core/models/question.dart';
import '../../../../../../../core/models/question_kind.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../cubit/editor_cubit.dart';
import '../../../../widgets/image_url_dialog.dart';
import '../../../../widgets/question_edit_sheet.dart';
import '../../../../widgets/video_search_dialog.dart';

class QuestionsBottomBar extends StatelessWidget {
  final bool enabled;
  final String formId;

  const QuestionsBottomBar({super.key, required this.enabled, required this.formId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.purpleDark.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleDark.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BarButton(
                        icon: CupertinoIcons.add_circled_solid,
                        label: 'Question',
                        enabled: enabled,
                        onTap: () => _openNewQuestionDraft(context),
                      ),
                      _BarButton(
                        icon: CupertinoIcons.photo_fill,
                        label: 'Image',
                        enabled: enabled,
                        onTap: () async {
                          final url = await showImageUrlDialog(
                            context,
                            onGalleryUpload: (bytes, mimeType) =>
                                getIt<DriveClient>().uploadImage(bytes, mimeType),
                          );
                          if (url != null && context.mounted) cubit.addImageItem(url);
                        },
                      ),
                      _BarButton(
                        icon: CupertinoIcons.textformat_alt,
                        label: 'Text',
                        enabled: enabled,
                        onTap: () => cubit.addTextBlock(),
                      ),
                      _BarButton(
                        icon: CupertinoIcons.play_circle_fill,
                        label: 'Video',
                        enabled: enabled,
                        onTap: () async {
                          final video = await showVideoSearchDialog(context);
                          if (video != null && context.mounted) {
                            cubit.addVideoItem(video.videoId, video.title);
                          }
                        },
                      ),
                      _BarButton(
                        icon: CupertinoIcons.rectangle_stack_fill,
                        label: 'Section',
                        enabled: enabled,
                        onTap: () => cubit.addSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openNewQuestionDraft(BuildContext context) {
  final state = context.read<EditorCubit>().state;
  if (state is! EditorLoaded) return;
  final draftItem = Item(
    itemId: '_draft',
    title: '',
    content: QuestionItemContent(
      question: Question(questionId: '_draft_q', kind: const TextQuestion()),
    ),
  );
  final sections = state.form.items
      .where((i) => i.content is PageBreakItemContent)
      .toList();
  QuestionEditSheet.show(
    context,
    draftItem,
    sections,
    isQuiz: state.form.settings.quizSettings.isQuiz,
    isDraft: true,
  );
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled ? Colors.white : Colors.white.withValues(alpha: 0.35);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }
}
