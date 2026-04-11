import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/api/youtube_client.dart';

const _purple = Color(0xFF772FC0);

/// Shows a dialog that lets the user search YouTube and pick a video.
/// Returns the selected [YouTubeVideo], or null if cancelled.
Future<YouTubeVideo?> showVideoSearchDialog(BuildContext context) {
  return showDialog<YouTubeVideo>(
    context: context,
    builder: (_) => const _VideoSearchDialog(),
  );
}

class _VideoSearchDialog extends StatefulWidget {
  const _VideoSearchDialog();

  @override
  State<_VideoSearchDialog> createState() => _VideoSearchDialogState();
}

class _VideoSearchDialogState extends State<_VideoSearchDialog> {
  final _client = YouTubeClient();
  final _controller = TextEditingController();
  List<YouTubeVideo> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await _client.search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Search failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Video'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            _SearchField(
              controller: _controller,
              onSubmit: _search,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, textAlign: TextAlign.center),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Search for a YouTube video above.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _VideoTile(
        video: _results[i],
        onTap: () => Navigator.of(context).pop(_results[i]),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _SearchField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search YouTube',
              filled: true,
              fillColor: const Color(0xFFF3F0FA),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: _purple,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Icon(Icons.search, size: 20),
        ),
      ],
    );
  }
}

class _VideoTile extends StatelessWidget {
  final YouTubeVideo video;
  final VoidCallback onTap;

  const _VideoTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                video.thumbnailUrl,
                width: 100,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 100,
                  height: 56,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.video_library_outlined,
                      color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
