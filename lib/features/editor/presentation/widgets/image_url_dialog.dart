import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _purple = Color(0xFF772FC0);

/// Shows a dialog where the user can paste a public image URL or pick from
/// the device gallery.
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
  return showDialog<String>(
    context: context,
    builder: (_) => _ImageUrlDialog(onGalleryUpload: onGalleryUpload),
  );
}

// ─── Dialog ───────────────────────────────────────────────────────────────────

enum _UploadState { idle, uploading, error }

class _ImageUrlDialog extends StatefulWidget {
  const _ImageUrlDialog({this.onGalleryUpload});

  final Future<String> Function(Uint8List bytes, String mimeType)?
      onGalleryUpload;

  @override
  State<_ImageUrlDialog> createState() => _ImageUrlDialogState();
}

class _ImageUrlDialogState extends State<_ImageUrlDialog> {
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

    return AlertDialog(
      title: const Text('Add Image'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gallery button ────────────────────────────────────────────
            if (widget.onGalleryUpload != null) ...[
              _GalleryButton(
                uploading: uploading,
                error: _uploadError,
                onTap: uploading ? null : _onPickFromGallery,
              ),
              const _OrDivider(),
            ],
            // ── URL field ─────────────────────────────────────────────────
            TextField(
              controller: _controller,
              autofocus: widget.onGalleryUpload == null,
              enabled: !uploading,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Paste public image URL',
                filled: true,
                fillColor: const Color(0xFFF3F0FA),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _onAdd(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // ── URL preview ───────────────────────────────────────────────
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final url = _controller.text.trim();
                if (url.isEmpty) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            height: 140,
                            color: const Color(0xFFF3F0FA),
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (_, _, _) => Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "Couldn't load image. Check the URL.",
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: uploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (!uploading && _controller.text.trim().isNotEmpty)
              ? _onAdd
              : null,
          style: FilledButton.styleFrom(backgroundColor: _purple),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ─── Gallery button ────────────────────────────────────────────────────────────

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({
    required this.uploading,
    required this.onTap,
    this.error,
  });

  final bool uploading;
  final VoidCallback? onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onTap,
          icon: uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _purple),
                )
              : const Icon(Icons.photo_library_outlined, color: _purple),
          label: Text(
            uploading ? 'Uploading…' : 'Pick from Gallery',
            style: const TextStyle(color: _purple),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _purple),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            error!,
            style: TextStyle(
                color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── OR divider ───────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'or',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
