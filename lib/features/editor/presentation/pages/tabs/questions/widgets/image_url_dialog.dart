import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';

/// Shows a bottom sheet where the user can paste a public image URL or pick
/// from the device gallery.
///
/// [onGalleryUpload] receives the raw image bytes + mime type and must return
/// a publicly accessible URL (e.g. after uploading to Drive). When null the
/// gallery option is hidden.
///
/// Returns the final URL string, or null if cancelled.
Future<String?> showImageUrlDialog(
  BuildContext context, {
  Future<String> Function(Uint8List bytes, String mimeType)? onGalleryUpload,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ImageUrlSheet(onGalleryUpload: onGalleryUpload),
  );
}

// ─── Sheet ─────────────────────────────────────────────────────────────────────

enum _UploadState { idle, uploading, error }

class _ImageUrlSheet extends StatefulWidget {
  const _ImageUrlSheet({this.onGalleryUpload});

  final Future<String> Function(Uint8List bytes, String mimeType)?
      onGalleryUpload;

  @override
  State<_ImageUrlSheet> createState() => _ImageUrlSheetState();
}

class _ImageUrlSheetState extends State<_ImageUrlSheet> {
  final _controller = TextEditingController();
  _UploadState _uploadState = _UploadState.idle;
  String? _uploadError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAdd() {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    Navigator.of(context).pop(url);
  }

  Future<void> _onPickFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() {
      _uploadState = _UploadState.uploading;
      _uploadError = null;
    });

    try {
      final bytes = await picked.readAsBytes();
      final mimeType = _mimeTypeFromExtension(picked.name);
      final url = await widget.onGalleryUpload!(bytes, mimeType);
      if (mounted) Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadState = _UploadState.error;
          _uploadError = 'Upload failed. Try again.';
        });
      }
    }
  }

  String _mimeTypeFromExtension(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final uploading = _uploadState == _UploadState.uploading;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
          bottom: viewInsets > 0 ? viewInsets : safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Image',
                    style: AppTextStyles.screenHeader.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed:
                      uploading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.normal,
                      color: uploading ? AppColors.textSecondary : AppColors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.separator),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Gallery button ──────────────────────────────────────────
                if (widget.onGalleryUpload != null) ...[
                  GestureDetector(
                    onTap: uploading ? null : _onPickFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (uploading)
                            const CupertinoActivityIndicator(
                                color: AppColors.purple, radius: 9)
                          else
                            const Icon(CupertinoIcons.photo,
                                size: 18, color: AppColors.purple),
                          const SizedBox(width: 8),
                          Text(
                            uploading ? 'Uploading…' : 'Pick from Gallery',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_uploadError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _uploadError!,
                      style: AppTextStyles.meta.copyWith(
                          fontWeight: FontWeight.normal, color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // OR divider
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(color: AppColors.separator)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'or',
                          style: AppTextStyles.meta.copyWith(
                              fontWeight: FontWeight.normal),
                        ),
                      ),
                      const Expanded(
                          child: Divider(color: AppColors.separator)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // ── URL field ───────────────────────────────────────────────
                const Text(
                  'Image URL',
                  style: AppTextStyles.meta,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: widget.onGalleryUpload == null,
                  enabled: !uploading,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Paste public image URL',
                    hintStyle: const TextStyle(
                        fontSize: 15, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.purpleTintDeep,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.purple, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _onAdd(),
                  onChanged: (_) => setState(() {}),
                ),
                // ── URL preview ─────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final url = _controller.text.trim();
                    if (url.isEmpty) return const SizedBox(height: 4);
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      height: 160,
                                      color: AppColors.purpleTintDeep,
                                      child: const Center(
                                        child: CupertinoActivityIndicator(),
                                      ),
                                    ),
                          errorBuilder: (_, _, _) => Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.purpleTintDeep,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "Couldn't load image — check the URL.",
                                style: AppTextStyles.meta.copyWith(
                                    fontWeight: FontWeight.normal),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // ── Add button ──────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final canAdd = !uploading &&
                        _controller.text.trim().isNotEmpty;
                    return GestureDetector(
                      onTap: canAdd ? _onAdd : null,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: canAdd
                              ? AppColors.purple
                              : AppColors.purple.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Add',
                          style: AppTextStyles.cardTitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
