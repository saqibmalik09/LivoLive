import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kWaveTenantBaseUrl = 'https://gateway.skliveparty.online';

bool isWaveGameUrl(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return host == 'wavegames.online' || host.endsWith('.wavegames.online');
}

bool isWaveGameConfig(Map<String, dynamic>? gameConfig) {
  if (gameConfig == null) return false;
  final nested = gameConfig['config_data'];
  final cfg = nested is Map ? nested : gameConfig;
  return cfg['provider']?.toString() == 'wave';
}

bool isWaveCloseUrl(String navUrl) {
  final uri = Uri.tryParse(navUrl.trim());
  if (uri == null) return false;
  if (uri.scheme == 'xani-games' || uri.scheme == 'sklive-games') {
    return uri.host == 'close' || uri.path.contains('close');
  }
  return uri.fragment == 'wave-game-close';
}

String openWavePlayUrl(String playUrl, String token) {
  final encoded = Uri.encodeQueryComponent(token);
  var url = playUrl
      .replaceAll('{token}', encoded)
      .replaceAll('%7Btoken%7D', encoded)
      .replaceAll('%7btoken%7d', encoded);
  if (!url.contains('tenantBase=')) {
    final sep = url.contains('?') ? '&' : '?';
    url = '$url${sep}tenantBase=${Uri.encodeQueryComponent(kWaveTenantBaseUrl)}';
  }
  return url;
}

const String waveCloseBridgeJs = '''
(function(){
  function closeGame(){
    try { window.flutter_inappwebview.callHandler('waveGameClose'); } catch (e) {}
  }
  window.WaveGameHost = { close: closeGame, closeGame: closeGame };
  window.XaniNative = { close: closeGame, closeGame: closeGame };
  window.addEventListener('message', function(ev){
    var data = ev && ev.data;
    if (!data) return;
    if (typeof data === 'string') {
      try { data = JSON.parse(data); } catch (e) { return; }
    }
    if (data && data.type === 'wave-game-close') closeGame();
  });
})();
''';

Future<Map<String, dynamic>?> fetchWaveCatalog() async {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null || token.isEmpty) return null;
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 6);
  try {
    final uri = Uri.parse(
      '${AppConstants.realtimeGatewayUrl}/v1/games/catalog',
    );
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 6));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      await res.drain<void>();
      return null;
    }
    final body = await res.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  } catch (e) {
    debugPrint('[wave] catalog failed: $e');
    return null;
  } finally {
    client.close(force: true);
  }
}

List<Map<String, dynamic>> _cards(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

Map<String, dynamic>? _roomGame(Map<String, dynamic> card, int sortOrder) {
  final id = card['game_id'] ?? card['id'];
  final play = card['play_url']?.toString() ?? '';
  if (id == null || play.isEmpty) return null;
  final height = (card['sheet_height_percent'] as num?)?.toDouble() ?? 60;
  return {
    'id': 'wave-$id',
    'slug': card['route_slug']?.toString().isNotEmpty == true
        ? card['route_slug'].toString()
        : 'wave-$id',
    'name': card['name']?.toString() ?? 'Game',
    'display_name': card['name']?.toString() ?? 'Game',
    'icon_url': card['listing_image']?.toString() ?? '',
    'game_url': play,
    'sort_order': sortOrder,
    'maintenance_mode': false,
    'webview_height_percent': height,
    'category_id': 'wave',
    'category_name': 'Wave Games',
    'category_sort': 10000,
    'config_data': {'provider': 'wave', 'game_id': id},
  };
}

Future<List<Map<String, dynamic>>> fetchWaveRoomGames() async {
  final catalog = await fetchWaveCatalog();
  if (catalog == null) return const [];
  final half = _cards(catalog['half_mode_games']);
  final source = half.isNotEmpty ? half : _cards(catalog['games']);
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < source.length; i++) {
    final game = _roomGame(source[i], 1000 - i);
    if (game != null) out.add(game);
  }
  return out;
}

List<Map<String, dynamic>> waveFullCards(Map<String, dynamic>? catalog) {
  if (catalog == null) return const [];
  return _cards(catalog['games']);
}
