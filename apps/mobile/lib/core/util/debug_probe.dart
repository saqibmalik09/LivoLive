// #region agent log
// Temporary runtime instrumentation for the seat-take voice delay (session
// dd7392). Posts one NDJSON record per call to the debug log server and also
// prints it to logcat as a fallback. Removed once the investigation closes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugProbe {
  const DebugProbe._();

  static const String _sessionId = 'dd7392';
  static const String _endpoint =
      'http://127.0.0.1:7873/ingest/291e4f02-f0b3-416b-8e29-7d96f86f8a6c';
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  static String get _uid8 {
    try {
      final id = Supabase.instance.client.auth.currentUser?.id;
      return id == null || id.length < 8 ? '-' : id.substring(0, 8);
    } catch (_) {
      return '-';
    }
  }

  static void log(
    String hypothesisId,
    String location,
    String message, [
    Map<String, Object?> data = const {},
  ]) {
    final body = jsonEncode({
      'sessionId': _sessionId,
      'runId': 'run1',
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': {'uid8': _uid8, ...data},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('[DBGPROBE] $body');
    unawaited(_send(body));
  }

  static Future<void> _send(String body) async {
    try {
      final req = await _client.postUrl(Uri.parse(_endpoint));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Debug-Session-Id', _sessionId);
      req.write(body);
      final res = await req.close();
      await res.drain<void>();
    } catch (_) {
      // Instrumentation only: the logcat line above is the fallback.
    }
  }
}
// #endregion
