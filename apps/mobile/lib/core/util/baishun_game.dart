import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/tulasi_game.dart';

const String kBaishunAppChannel = 'sklive';
const int kBaishunAppId = 8740978342;
const int kBaishunGsp = 101;

const String kBaishunCurrencyIcon =
    'https://bsyx-store.s3.ap-southeast-1.amazonaws.com/game-icons/20230906-163004.png';

const String kBaishunShowroomRoomId = '0';

bool isBaishunGameConfig(Map<String, dynamic>? game) {
  if (game == null) return false;
  final cfg = game['config_data'];
  return cfg is Map && cfg['provider']?.toString() == 'baishun';
}

bool isBaishunHost(String? host) {
  final h = host?.toLowerCase() ?? '';
  if (h.isEmpty) return false;
  return h.endsWith('.jieyou.shop') ||
      h.contains('jieyou.shop') ||
      h.endsWith('.cloudfront.net') ||
      h.contains('cloudfront.net');
}

bool isBaishunGameUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return isBaishunHost(uri.host);
}

bool isBaishunLandscape(Map<String, dynamic>? game) {
  if (game == null) return false;
  final cfg = game['config_data'];
  if (cfg is Map) {
    final orientation = cfg['game_orientation'];
    if (orientation == 2 || orientation?.toString() == '2') return true;
    final v = cfg['isLandscape'] ?? cfg['is_landscape'];
    if (v == true || v == 1 || v?.toString() == 'true') return true;
  }
  return isTulasiLandscape(game);
}

/// The package URL a given viewer should load for [game].
///
/// An admin can point a game at a candidate package for named testers only
/// (`test_game_url` + `test_user_ids`). Everyone else keeps the normal URL, so
/// a URL that turns out to be broken can only affect the people testing it —
/// swapping `game_url` outright takes the game down for every player at once.
String resolveBaishunGameUrl(
  Map<String, dynamic>? game, {
  String? fallbackUrl,
}) {
  final testUrl = game?['test_game_url']?.toString().trim() ?? '';
  if (testUrl.isNotEmpty && _viewerIsTester(game?['test_user_ids'])) {
    return testUrl;
  }
  final cfg = game?['config_data'];
  if (cfg is Map) {
    final download = cfg['download_url']?.toString().trim() ?? '';
    if (download.isNotEmpty) return download;
  }
  final fromRow = game?['game_url']?.toString().trim() ?? '';
  if (fromRow.isNotEmpty) return fromRow;
  return fallbackUrl?.trim() ?? '';
}

bool _viewerIsTester(dynamic rawIds) {
  if (rawIds is! List || rawIds.isEmpty) return false;
  final me = Supabase.instance.client.auth.currentUser?.id;
  if (me == null || me.isEmpty) return false;
  for (final id in rawIds) {
    if (id?.toString().trim().toLowerCase() == me.toLowerCase()) return true;
  }
  return false;
}

String baishunLanguageCode(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode.toLowerCase();
  if (code == 'zh' || code == 'cn') return '1';
  if (code == 'ar') return '3';
  if (code == 'hi') return '4';
  return '2';
}

Future<String?> mintBaishunLaunchCode() async {
  final token = currentSkAccessToken();
  if (token == null || token.isEmpty) return null;
  try {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final resp = await dio.post<Map<String, dynamic>>(
      '${AppConstants.realtimeGatewayUrl}/v1/api/internal/baishun_mint_code',
    );
    final data = resp.data;
    if (data == null || data['ok'] != true) return null;
    return data['code']?.toString();
  } catch (e) {
    debugPrint('[baishun] mint_code failed: $e');
    return null;
  }
}

const String baishunNativeBridgeBootstrapJs = r'''
(function () {
  if (window.__skBaishunBridge) return;
  window.__skBaishunBridge = true;
  function callHandler(name, params) {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler(name, params);
      }
    } catch (e) {}
  }
  window.NativeBridge = {
    getConfig: function (p) { callHandler('baishunGetConfig', p); },
    destroy: function (p) { callHandler('baishunDestroy', p); },
    gameRecharge: function (p) { callHandler('baishunGameRecharge', p); },
    gameLoaded: function (p) { callHandler('baishunGameLoaded', p); }
  };
  if (!window.webkit) window.webkit = {};
  if (!window.webkit.messageHandlers) window.webkit.messageHandlers = {};
  var names = ['getConfig', 'destroy', 'gameRecharge', 'gameLoaded'];
  for (var i = 0; i < names.length; i++) {
    (function (n) {
      var handler = 'baishun' + n.charAt(0).toUpperCase() + n.slice(1);
      window.webkit.messageHandlers[n] = {
        postMessage: function (body) {
          var p = typeof body === 'string' ? body : JSON.stringify(body || {});
          callHandler(handler, p);
        }
      };
    })(names[i]);
  }
})();
''';

Future<Map<String, dynamic>?> _loadBaishunUserProfile() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('short_id, username')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  } catch (e) {
    debugPrint('[baishun] profile load failed: $e');
    return null;
  }
}

String _parseJsCallback(dynamic raw) {
  if (raw == null) return 'jsCallback';
  if (raw is Map) {
    return raw['jsCallback']?.toString() ?? 'jsCallback';
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return 'jsCallback';
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map && decoded['jsCallback'] != null) {
      return decoded['jsCallback'].toString();
    }
  } catch (_) {}
  return 'jsCallback';
}

Future<void> wireBaishunWebView({
  required InAppWebViewController controller,
  required BuildContext context,
  required String roomId,
  String gameMode = '3',
  required VoidCallback onDestroy,
  required VoidCallback onGameLoaded,
  required Future<void> Function() onRecharge,
}) async {
  Future<void> replyGetConfig(dynamic raw) async {
    final jsCallback = _parseJsCallback(raw);
    final profile = await _loadBaishunUserProfile();
    final shortId = profile?['short_id']?.toString();
    if (shortId == null || shortId.isEmpty) return;
    final code = await mintBaishunLaunchCode();
    if (code == null || code.isEmpty) return;

    final payload = {
      'appChannel': kBaishunAppChannel,
      'appId': kBaishunAppId,
      'userId': shortId,
      'code': code,
      'roomId': roomId.isNotEmpty ? roomId : kBaishunShowroomRoomId,
      'gameMode': gameMode,
      'language': baishunLanguageCode(context),
      'gameConfig': {'sceneMode': 0, 'currencyIcon': kBaishunCurrencyIcon},
      'gsp': kBaishunGsp,
    };
    final js = '$jsCallback(${jsonEncode(payload)})';
    try {
      await controller.evaluateJavascript(source: js);
    } catch (e) {
      debugPrint('[baishun] getConfig reply failed: $e');
    }
  }

  controller.addJavaScriptHandler(
    handlerName: 'baishunGetConfig',
    callback: (args) async {
      final raw = args.isNotEmpty ? args.first : null;
      await replyGetConfig(raw);
      return null;
    },
  );
  controller.addJavaScriptHandler(
    handlerName: 'baishunDestroy',
    callback: (args) async {
      onDestroy();
      return null;
    },
  );
  controller.addJavaScriptHandler(
    handlerName: 'baishunGameRecharge',
    callback: (args) async {
      await onRecharge();
      return null;
    },
  );
  controller.addJavaScriptHandler(
    handlerName: 'baishunGameLoaded',
    callback: (args) async {
      onGameLoaded();
      return null;
    },
  );
}

Future<void> notifyBaishunWalletUpdate(
  InAppWebViewController controller, {
  required String userId,
}) async {
  final payload = jsonEncode({'userId': userId});
  try {
    await controller.evaluateJavascript(source: 'walletUpdate($payload);');
  } catch (e) {
    debugPrint('[baishun] walletUpdate failed: $e');
  }
}

Future<String?> baishunUserIdForWallet() async {
  final profile = await _loadBaishunUserProfile();
  return profile?['short_id']?.toString();
}
