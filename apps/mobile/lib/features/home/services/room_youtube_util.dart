String? parseYoutubeVideoId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (RegExp(r'^[\w-]{11}$').hasMatch(trimmed)) {
    return trimmed;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (uri.host.contains('youtu.be')) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (id != null && id.length == 11) return id;
  }

  if (uri.host.contains('youtube.com') ||
      uri.host.contains('youtube-nocookie.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.length == 11) return v;

    final segments = uri.pathSegments;
    if (segments.length >= 2) {
      if (segments[0] == 'shorts' ||
          segments[0] == 'embed' ||
          segments[0] == 'live') {
        final id = segments[1];
        if (id.length == 11) return id;
      }
    }
  }

  return null;
}

bool isValidYoutubeVideoId(String? videoId) {
  if (videoId == null || videoId.isEmpty) return false;
  return RegExp(r'^[\w-]{11}$').hasMatch(videoId);
}
