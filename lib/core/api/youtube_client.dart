import 'dart:convert';

import 'package:http/http.dart' as http;

class YouTubeVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  const YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  String get youtubeUri => 'https://www.youtube.com/watch?v=$videoId';
}

class YouTubeClient {
  static const _apiKey = 'AIzaSyA1GvPj9u0RtoVZo6QSm3eDiCGQMg_Tf7Y';

  static const _searchUrl =
      'https://www.googleapis.com/youtube/v3/search';

  Future<List<YouTubeVideo>> search(String query) async {
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'part': 'snippet',
      'type': 'video',
      'q': query,
      'key': _apiKey,
      'maxResults': '10',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('YouTube search failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? [];

    return items
        .map((e) => e as Map<String, dynamic>)
        .where((e) => e['id']?['videoId'] != null)
        .map((e) {
          final snippet = e['snippet'] as Map<String, dynamic>;
          final thumbnails = snippet['thumbnails'] as Map<String, dynamic>;
          final thumb = (thumbnails['medium'] ?? thumbnails['default'])
              as Map<String, dynamic>;
          return YouTubeVideo(
            videoId: e['id']['videoId'] as String,
            title: snippet['title'] as String,
            thumbnailUrl: thumb['url'] as String,
          );
        })
        .toList();
  }
}
