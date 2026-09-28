import 'package:app_links/app_links.dart';

class RoomDeepLinkService {
  RoomDeepLinkService._();

  static const String scheme = 'sklive';
  static const String roomHost = 'room';

  static String? _pendingRoomId;
  static final AppLinks _appLinks = AppLinks();

  static String buildRoomLink(String roomId) => '$scheme://$roomHost/$roomId';

  static String buildShareWebLink(String roomId, String sharePageBaseUrl) {
    final separator = sharePageBaseUrl.contains('?') ? '&' : '?';
    return '$sharePageBaseUrl${separator}id=${Uri.encodeQueryComponent(roomId)}';
  }

  static String buildPublicRoomLink(String roomId, String publicBaseUrl) {
    final base = publicBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/r/${Uri.encodeComponent(roomId)}';
  }

  static Future<void> captureInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      _setPendingFromUri(uri);
    } catch (_) {}
  }

  static void listen(void Function(String roomId) onRoomId) {
    _appLinks.uriLinkStream.listen((uri) {
      final roomId = parseRoomId(uri);
      if (roomId != null) onRoomId(roomId);
    });
  }

  static String? peekPending() => _pendingRoomId;

  static String? consumePending() {
    final id = _pendingRoomId;
    _pendingRoomId = null;
    return id;
  }

  static void setPending(String roomId) {
    _pendingRoomId = roomId;
  }

  static void _setPendingFromUri(Uri? uri) {
    final id = parseRoomId(uri);
    if (id != null) _pendingRoomId = id;
  }

  static String? parseRoomId(Uri? uri) {
    if (uri == null) return null;

    if (uri.scheme == scheme && uri.host == roomHost) {
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.join('/');
      }
      final path = uri.path;
      if (path.length > 1) return path.substring(1);
    }

    final queryId = uri.queryParameters['id'] ?? uri.queryParameters['roomId'];
    if (queryId != null && queryId.isNotEmpty) return queryId;

    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'r') {
      return uri.pathSegments[1];
    }

    if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'room') {
      return uri.pathSegments[1];
    }

    return null;
  }
}
