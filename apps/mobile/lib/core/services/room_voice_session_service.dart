import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/background_service.dart';

class RoomVoiceSessionService {
  static Completer<void>? _leaveGate;
  static Future<void> _chain = Future.value();
  static String? _activeRoomId;
  static bool _sessionActive = false;
  static Completer<void>? _readyCompleter;

  static String? get activeZegoRoomId => _activeRoomId;

  static bool get isSessionActive => _sessionActive;

  static bool isLoggedInto(String roomId) =>
      _sessionActive && _activeRoomId == roomId;

  static Future<T> runSerialized<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        result.complete(await action());
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    _chain = _chain.catchError((Object _) {});
    return result.future;
  }

  static void markLoggedIn(String roomId) {
    _activeRoomId = roomId;
    _sessionActive = true;
    final pending = _readyCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    _readyCompleter = Completer<void>()..complete();
  }

  static void markLoggedOut() {
    _activeRoomId = null;
    _sessionActive = false;
    _readyCompleter = Completer<void>();
  }

  static Future<bool> waitUntilReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_sessionActive) return true;
    final completer = _readyCompleter ??= Completer<void>();
    try {
      await completer.future.timeout(timeout);
      return _sessionActive;
    } catch (_) {
      return _sessionActive;
    }
  }

  static void markEngineCreated() {}

  static Future<void> configureAudioOnlyPublish() async {}

  static Future<void> startPlayingTracked(String streamId) async {}

  static Future<void> stopPlayingTracked(String streamId) async {}

  static Future<void> stopAllRemotePlayback() async {}

  static Future<void> stopLocalPublish() async {}

  static Future<void> logoutRoomFast(String roomId) async {
    markLoggedOut();
  }

  static Future<void> forceDestroyEngine() async {
    try {
      BackgroundService.stop();
    } catch (_) {}
    markLoggedOut();
  }

  static Future<void> leaveVoiceRoom(
    String roomId,
    String? userId, {
    bool skipPresenceUntrack = false,
    bool skipSeatDelete = false,
  }) async {
    final normalizedRoomId = roomId.trim();
    debugPrint('[VOICE] leaveVoiceRoom room=$normalizedRoomId user=$userId');

    final inFlight = _leaveGate;
    if (inFlight != null) {
      await inFlight.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
      return;
    }

    final gate = Completer<void>();
    _leaveGate = gate;
    try {
      await runSerialized(() async {
        try {
          BackgroundService.stop();
        } catch (e) {
          debugPrint('[VOICE] background service stop: $e');
        }
        markLoggedOut();
        if (!skipSeatDelete) {
          await _releaseSeat(normalizedRoomId, userId);
        }
        if (!skipPresenceUntrack) {
          await _untrackRoomPresence(normalizedRoomId);
        }
      });
    } catch (e) {
      debugPrint('[VOICE] leaveVoiceRoom error: $e');
      await forceDestroyEngine();
    } finally {
      if (!gate.isCompleted) gate.complete();
      if (identical(_leaveGate, gate)) {
        _leaveGate = null;
      }
    }
  }

  static Future<void> cleanupOrphanedSession(String? userId) async {
    await runSerialized(() async {
      if (_sessionActive) {
        debugPrint('[VOICE] skip orphan cleanup — session active');
        return;
      }
      await forceDestroyEngine();
    });
    if (userId != null) {
      try {
        await Supabase.instance.client
            .from('room_seats')
            .delete()
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[VOICE] orphan seat cleanup: $e');
      }
    }
  }

  static Future<void> _releaseSeat(String roomId, String? userId) async {
    if (userId == null) return;
    try {
      final deleted = await Supabase.instance.client
          .from('room_seats')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId)
          .select('id')
          .timeout(const Duration(seconds: 4));
      if (deleted.isEmpty) {
        await Supabase.instance.client
            .from('room_seats')
            .delete()
            .eq('user_id', userId)
            .select('id')
            .timeout(const Duration(seconds: 4));
        debugPrint('[VOICE] seat fallback delete by user_id');
      } else {
        debugPrint('[VOICE] seat deleted for room: ${deleted.length}');
      }
    } catch (e) {
      debugPrint('[VOICE] seat delete: $e');
    }
  }

  static Future<void> _untrackRoomPresence(String roomId) async {
    try {
      final client = Supabase.instance.client;
      final channel = client.channel('room:$roomId');
      final completer = Completer<void>();
      var teardownStarted = false;
      channel.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (teardownStarted) return;
          teardownStarted = true;
          try {
            await channel.untrack().timeout(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('[VOICE] untrack on subscribed channel: $e');
          }
          try {
            await channel.unsubscribe().timeout(const Duration(seconds: 2));
            await client
                .removeChannel(channel)
                .timeout(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('[VOICE] channel cleanup: $e');
          }
          if (!completer.isCompleted) completer.complete();
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          if (teardownStarted) {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          teardownStarted = true;
          try {
            await client
                .removeChannel(channel)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
          if (!completer.isCompleted) completer.complete();
        }
      });
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          if (teardownStarted) return;
          teardownStarted = true;
          try {
            await channel.unsubscribe().timeout(const Duration(seconds: 2));
            await client
                .removeChannel(channel)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
        },
      );
      debugPrint('[VOICE] presence untracked');
    } catch (e) {
      debugPrint('[VOICE] presence untrack: $e');
    }
  }
}
