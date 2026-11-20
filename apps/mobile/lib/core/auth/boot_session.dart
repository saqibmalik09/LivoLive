import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/util/app_constants.dart';

/// Where the first route sends the user. Null until the local probe finishes.
/// The probe never waits on the network or the Android keystore.
enum BootDestination { home, login }

class _PrefsRead {
  const _PrefsRead({
    required this.completed,
    this.legacySession,
    this.cachedUserId,
  });

  final bool completed;
  final String? legacySession;
  final String? cachedUserId;

  static const incomplete = _PrefsRead(completed: false);
}

/// Decides home vs login from SharedPreferences already on the device.
///
/// The keystore session (flutter_secure_storage) can take 10–20s and runs on
/// the Android main thread, so it is not read here. A cached user id or a
/// legacy prefs session opens home. Anything else opens login. Supabase
/// restores the secure session after that route is up and the router moves
/// login → home when the session appears.
class BootSession extends ChangeNotifier {
  BootSession._();

  static final BootSession instance = BootSession._();

  static const prefsReadBudget = Duration(milliseconds: 200);
  static const cachedUserIdPrefsKey = 'livo_cached_user_id';

  BootDestination? destination;

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_runProbe());
  }

  /// Completes with [destination]. Starts the probe if needed. A hung prefs
  /// read cannot leave the caller waiting: after 800ms the route is login.
  Future<BootDestination> whenDecided() async {
    start();
    final existing = destination;
    if (existing != null) return existing;

    final done = Completer<BootDestination>();
    void listener() {
      final next = destination;
      if (next == null) return;
      removeListener(listener);
      if (!done.isCompleted) done.complete(next);
    }

    addListener(listener);
    final raced = destination;
    if (raced != null) {
      removeListener(listener);
      return raced;
    }

    try {
      return await done.future.timeout(const Duration(milliseconds: 800));
    } on TimeoutException {
      removeListener(listener);
      resolveIfPending(BootDestination.login);
      return destination ?? BootDestination.login;
    }
  }

  /// First decision wins. Used when the prefs read never reports back.
  void resolveIfPending(BootDestination next) => _decide(next);

  Future<void> _runProbe() async {
    try {
      await _probe();
    } catch (e) {
      debugPrint('[BOOT] probe failed: $e');
      _decide(BootDestination.login);
    }
  }

  static String sessionPrefsKey() {
    final host = Uri.parse(AppConstants.supabaseUrl).host.split('.').first;
    return 'sb-$host-auth-token';
  }

  static String? userIdFromPersistedSession(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      final map = decoded is String ? jsonDecode(decoded) : decoded;
      if (map is! Map) return null;
      final user = map['user'];
      if (user is! Map) return null;
      final id = user['id']?.toString().trim() ?? '';
      if (id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  static Future<void> rememberUserId(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(cachedUserIdPrefsKey) == id) return;
      await prefs.setString(cachedUserIdPrefsKey, id);
    } catch (e) {
      debugPrint('[BOOT] cache user id failed: $e');
    }
  }

  static Future<void> clearCachedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cachedUserIdPrefsKey);
    } catch (e) {
      debugPrint('[BOOT] clear cached user id failed: $e');
    }
  }

  void _decide(BootDestination next) {
    if (destination != null) return;
    destination = next;
    debugPrint('[BOOT] splash → ${next.name}');
    notifyListeners();
  }

  void _rememberSession(String raw) {
    final userId = userIdFromPersistedSession(raw);
    if (userId != null) unawaited(rememberUserId(userId));
  }

  static bool _filled(String? value) => value != null && value.isNotEmpty;

  Future<void> _probe() async {
    final prefs = await _budget(
      _readPrefs(sessionPrefsKey()),
      prefsReadBudget,
      _PrefsRead.incomplete,
    );

    if (_filled(prefs.legacySession)) {
      _rememberSession(prefs.legacySession!);
      _decide(BootDestination.home);
      return;
    }
    if (_filled(prefs.cachedUserId)) {
      _decide(BootDestination.home);
      return;
    }
    _decide(BootDestination.login);
  }

  Future<_PrefsRead> _readPrefs(String sessionKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _PrefsRead(
        completed: true,
        legacySession: prefs.getString(sessionKey),
        cachedUserId: prefs.getString(cachedUserIdPrefsKey),
      );
    } catch (e) {
      debugPrint('[BOOT] prefs read failed: $e');
      return _PrefsRead.incomplete;
    }
  }

  Future<T> _budget<T>(Future<T> future, Duration budget, T fallback) {
    return future.timeout(budget, onTimeout: () => fallback);
  }
}
