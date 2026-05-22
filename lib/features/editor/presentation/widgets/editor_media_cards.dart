import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/drive_client.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/editor_cubit.dart';
import 'image_url_dialog.dart';

class EditorImageCard extends StatelessWidget {
  final Item item;

  const EditorImageCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final content = item.content as ImageItemContent;
    final imageUrl =
        content.image.sourceUri ?? content.image.contentUri;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 180,
                child: Center(
                  child: Icon(CupertinoIcons.photo,
                      size: 40, color: AppColors.iconInactive),
                ),
              ),
            )
          else
            const SizedBox(
              height: 180,
              child: Center(
                child: Icon(CupertinoIcons.photo,
                    size: 40, color: AppColors.iconInactive),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _editImage(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(CupertinoIcons.pencil,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () =>
                      context.read<EditorCubit>().deleteItem(item.itemId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(CupertinoIcons.xmark,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editImage(BuildContext context) async {
    final cubit = context.read<EditorCubit>();
    final driveClient = getIt<DriveClient>();
    final url = await showImageUrlDialog(
      context,
      onGalleryUpload: (bytes, mimeType) =>
          driveClient.uploadImage(bytes, mimeType),
    );
    if (url != null && context.mounted) {
      final content = item.content as ImageItemContent;
      cubit.updateItemFull(
        item.copyWith(
          content: content.copyWith(
            image: content.image.copyWith(sourceUri: url),
          ),
        ),
      );
    }
  }
}

class EditorVideoCard extends StatelessWidget {
  final Item item;

  const EditorVideoCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final content = item.content as VideoItemContent;
    final videoId =
        Uri.tryParse(content.video.youtubeUri)?.queryParameters['v'];
    final thumbnailUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (thumbnailUrl != null)
                Image.network(
                  thumbnailUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 160,
                    color: AppColors.groupedBackground,
                    child: const Icon(CupertinoIcons.play_circle,
                        size: 48, color: AppColors.iconInactive),
                  ),
                )
              else
                Container(
                  height: 160,
                  color: AppColors.groupedBackground,
                  child: const Icon(CupertinoIcons.play_circle,
                      size: 48, color: AppColors.iconInactive),
                ),
              Container(
                width: 52,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.play_arrow_solid,
                    color: Colors.white, size: 22),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () =>
                      context.read<EditorCubit>().deleteItem(item.itemId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(CupertinoIcons.xmark,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text(
              item.title ?? content.caption ?? 'Video',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
