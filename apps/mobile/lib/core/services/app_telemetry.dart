import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppTelemetry {
  AppTelemetry._();

  static bool _initialized = false;
  static bool _collectionEnabled = false;
  static String? _appVersion;
  static final Map<String, String> _context = {};

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  static FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;
  static FirebasePerformance get _performance => FirebasePerformance.instance;

  static bool get isEnabled => _initialized && _collectionEnabled;

  static Future<void> initialize({bool? collectionEnabled}) async {
    if (_initialized) return;
    _collectionEnabled = collectionEnabled ?? !kDebugMode;
    await _crashlytics.setCrashlyticsCollectionEnabled(_collectionEnabled);
    await _performance.setPerformanceCollectionEnabled(_collectionEnabled);
    await _analytics.setAnalyticsCollectionEnabled(_collectionEnabled);
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      await _crashlytics.setCustomKey('app_version', info.version);
      await _analytics.setDefaultEventParameters({'app_version': info.version});
    } catch (_) {}
    _initialized = true;
  }

  static Future<void> setUser(
    String userId, {
    int? vipLevel,
    String? shortId,
  }) async {
    if (!isEnabled || userId.isEmpty) return;
    await _crashlytics.setUserIdentifier(userId);
    await _analytics.setUserId(id: userId);
    await _crashlytics.setCustomKey('user_id', userId);
    if (vipLevel != null) {
      await _crashlytics.setCustomKey('vip_level', vipLevel);
    }
    if (shortId != null && shortId.isNotEmpty) {
      await _crashlytics.setCustomKey('short_id', shortId);
    }
  }

  static Future<void> clearUser() async {
    if (!_initialized) return;
    await _crashlytics.setUserIdentifier('');
    await _analytics.setUserId(id: null);
    _context.remove('user_id');
  }

  static Future<void> setContext({
    String? roomId,
    String? tab,
    String? screen,
    bool? gatewayConnected,
  }) async {
    if (!_initialized) return;
    Future<void> setKey(String key, String? value) async {
      if (value == null || value.isEmpty) {
        _context.remove(key);
        return;
      }
      _context[key] = value;
      if (_collectionEnabled) {
        await _crashlytics.setCustomKey(key, value);
      }
    }

    await setKey('room_id', roomId);
    await setKey('nav_tab', tab);
    await setKey('screen', screen);
    if (gatewayConnected != null) {
      await setKey('gateway_connected', gatewayConnected.toString());
    }
  }

  static void log(String message) {
    if (!isEnabled) return;
    _crashlytics.log(message);
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? params,
  }) async {
    if (!isEnabled) return;
    final sanitized = <String, Object>{};
    params?.forEach((key, value) {
      if (value != null) sanitized[key] = value;
    });
    if (_appVersion != null) sanitized['app_version'] = _appVersion!;
    if (_context['screen'] != null) {
      sanitized['screen'] = _context['screen']!;
    }
    await _analytics.logEvent(name: name, parameters: sanitized);
  }

  static Future<void> logScreenView(String screenName) async {
    if (!isEnabled || screenName.isEmpty) return;
    await _analytics.logScreenView(screenName: screenName);
    await setContext(screen: screenName);
  }

  static Trace? startTrace(String name) {
    if (!isEnabled || name.isEmpty) return null;
    final trace = _performance.newTrace(name);
    unawaited(trace.start());
    return trace;
  }

  static Future<void> stopTrace(Trace? trace) async {
    if (trace == null || !isEnabled) return;
    try {
      await trace.stop();
    } catch (_) {}
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
    Map<String, String>? keys,
  }) async {
    if (!_initialized) {
      debugPrint('[Telemetry] $reason: $error');
      return;
    }
    if (reason != null) {
      await _crashlytics.setCustomKey('error_reason', reason);
    }
    if (keys != null) {
      for (final entry in keys.entries) {
        await _crashlytics.setCustomKey(entry.key, entry.value);
      }
    }
    await _crashlytics.recordError(error, stack, fatal: fatal, reason: reason);
  }

  static Future<T> traceAsync<T>(
    String operation,
    Future<T> Function() fn, {
    Map<String, String>? keys,
    int slowMs = 2000,
  }) async {
    final trace = startTrace(operation);
    keys?.forEach((key, value) {
      trace?.putAttribute(key, value);
    });
    final started = DateTime.now();
    try {
      final result = await fn();
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      trace?.putAttribute('duration_ms', elapsed.toString());
      if (elapsed >= slowMs) {
        unawaited(_reportSlowOp(operation, elapsed, keys));
      }
      return result;
    } catch (e, st) {
      unawaited(recordError(e, st, reason: operation, keys: keys));
      rethrow;
    } finally {
      unawaited(stopTrace(trace));
    }
  }

  static Future<void> _reportSlowOp(
    String operation,
    int durationMs,
    Map<String, String>? keys,
  ) async {
    log('SLOW $operation ${durationMs}ms');
    await recordError(
      Exception('slow_operation: $operation'),
      StackTrace.current,
      fatal: false,
      reason: 'perf_slow_op',
      keys: {
        'operation': operation,
        'duration_ms': durationMs.toString(),
        if (_context['screen'] != null) 'screen': _context['screen']!,
        ...?keys,
      },
    );
    await logEvent(
      'perf_slow_op',
      params: {'operation': operation, 'duration_ms': durationMs, ...?keys},
    );
  }
}
