import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/baishun_game.dart';
import 'package:sk_live/core/util/tulasi_game.dart';

class BaishunLaunchSession {
  Future<String?>? _shortId;
  Future<_LaunchCode?>? _prefetchedCode;

  void prefetch() {
    _shortId ??= _shortIdWithRetry();
    _prefetchedCode ??= _mintWithRetry();
  }

  Future<({String shortId, String code})?> configValues() async {
    final pending = _prefetchedCode;
    _prefetchedCode = null;
    var code = pending == null ? null : await pending;
    if (code == null || code.expiresSoon) code = await _mintWithRetry();
    if (code == null) return null;
    var shortId = code.shortId;
    if (shortId == null || shortId.isEmpty) {
      shortId = await (_shortId ??= _shortIdWithRetry());
    }
    if (shortId == null || shortId.isEmpty) {
      _shortId = null;
      return null;
    }
    return (shortId: shortId, code: code.value);
  }
}

class _LaunchCode {
  _LaunchCode(this.value, this.expiresAt, this.shortId);
  final String value;
  final DateTime? expiresAt;
  final String? shortId;

  bool get expiresSoon =>
      expiresAt != null &&
      expiresAt!.isBefore(DateTime.now().add(const Duration(seconds: 60)));
}

Future<String?> _shortIdWithRetry() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  for (var attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
    }
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('short_id')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      final id = row?['short_id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    } catch (e) {
      debugPrint('[baishun] short id load failed (attempt ${attempt + 1}): $e');
    }
  }
  return null;
}

Future<_LaunchCode?> _mintWithRetry() async {
  for (var attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final token = currentSkAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 12),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final resp = await dio.post<Map<String, dynamic>>(
        '${AppConstants.realtimeGatewayUrl}/v1/api/internal/baishun_mint_code',
      );
      final data = resp.data;
      final code = data?['code']?.toString();
      if (data != null &&
          data['ok'] == true &&
          code != null &&
          code.isNotEmpty) {
        return _LaunchCode(
          code,
          DateTime.tryParse(data['expires_at']?.toString() ?? ''),
          data['short_id']?.toString(),
        );
      }
    } catch (e) {
      debugPrint('[baishun] mint_code failed (attempt ${attempt + 1}): $e');
    }
  }
  return null;
}

String _jsCallbackName(dynamic raw) {
  if (raw == null) return 'jsCallback';
  if (raw is Map) return raw['jsCallback']?.toString() ?? 'jsCallback';
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

Future<void> wireBaishunWebViewWithLaunch({
  required InAppWebViewController controller,
  required BuildContext context,
  required String roomId,
  required String gameMode,
  required BaishunLaunchSession Function() session,
  required VoidCallback onDestroy,
  required VoidCallback onGameLoaded,
  required Future<void> Function() onRecharge,
  required VoidCallback onConfigFailed,
}) async {
  Future<void> replyGetConfig(dynamic raw) async {
    final jsCallback = _jsCallbackName(raw);
    final values = await session().configValues();
    if (values == null) {
      onConfigFailed();
      return;
    }
    if (!context.mounted) return;
    final payload = {
      'appChannel': kBaishunAppChannel,
      'appId': kBaishunAppId,
      'userId': values.shortId,
      'code': values.code,
      'roomId': roomId.isNotEmpty ? roomId : kBaishunShowroomRoomId,
      'gameMode': gameMode,
      'language': baishunLanguageCode(context),
      'gameConfig': {'sceneMode': 0, 'currencyIcon': kBaishunCurrencyIcon},
      'gsp': kBaishunGsp,
    };
    try {
      await controller.evaluateJavascript(
        source: '$jsCallback(${jsonEncode(payload)})',
      );
    } catch (e) {
      debugPrint('[baishun] getConfig reply failed: $e');
    }
  }

  controller.addJavaScriptHandler(
    handlerName: 'baishunGetConfig',
    callback: (args) async {
      await replyGetConfig(args.isNotEmpty ? args.first : null);
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
