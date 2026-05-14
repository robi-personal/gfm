import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/api/youtube_client.dart';
import '../../../../../core/theme/app_colors.dart';

/// Shows a bottom sheet that lets the user search YouTube and pick a video.
/// Returns the selected [YouTubeVideo], or null if cancelled.
Future<YouTubeVideo?> showVideoSearchDialog(BuildContext context) {
  return showModalBottomSheet<YouTubeVideo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _VideoSearchSheet(),
  );
}

class _VideoSearchSheet extends StatefulWidget {
  const _VideoSearchSheet();

  @override
  State<_VideoSearchSheet> createState() => _VideoSearchSheetState();
}

class _VideoSearchSheetState extends State<_VideoSearchSheet> {
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
    FocusManager.instance.primaryFocus?.unfocus();
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
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
                const Expanded(
                  child: Text(
                    'Add Video',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.purple, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.separator),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search YouTube',
                      hintStyle: const TextStyle(
                          fontSize: 15, color: AppColors.textSecondary),
                      prefixIcon: const Icon(CupertinoIcons.search,
                          size: 18, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.purpleTintDeep,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
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
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.search,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Results area
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: viewInsets > 0 ? viewInsets : safeBottom),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.play_rectangle,
                size: 48, color: AppColors.iconInactive),
            SizedBox(height: 12),
            Text(
              'Search for a YouTube video above.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.separator),
      itemBuilder: (context, i) => _VideoTile(
        video: _results[i],
        onTap: () => Navigator.of(context).pop(_results[i]),
      ),
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    video.thumbnailUrl,
                    width: 110,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 110,
                      height: 62,
                      color: AppColors.groupedBackground,
                      child: const Icon(CupertinoIcons.play_rectangle,
                          color: AppColors.iconInactive),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(CupertinoIcons.play_arrow_solid,
                        color: Colors.white, size: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
