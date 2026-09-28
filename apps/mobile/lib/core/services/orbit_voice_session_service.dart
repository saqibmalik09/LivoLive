import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:orbit_voice/orbit_voice.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrbitVoiceSessionService {
  OrbitVoiceSessionService._();

  static final OrbitEngine _e = OrbitEngine.instance;

  static String? _cachedOrbitRoomId;
  static String? _cachedSkLiveRoomId;

  static bool _fetcherWired = false;

  static bool _lastMicFailWasPermission = false;

  static const _denoisePrefKey = 'orbit_noise_cancellation';
  static bool _denoisePrefEnabled = true;
  static bool _denoisePrefHydrated = false;

  static Future<void> initWebRtcAudioAttributes() async {
    _wireFetcher();
    await ensureDenoisePrefLoaded();
    await OrbitAudioBootstrap.ensureInitialized();
  }

  static void _wireFetcher() {
    if (_fetcherWired) return;
    _fetcherWired = true;
    _e.sessionFetcher =
        ({
          required String roomId,
          required bool openMic,
          bool onSeat = false,
          bool leaveSeat = false,
          bool billingOnly = false,
        }) async {
          final map = await fetchSession(
            roomId: roomId,
            openMic: openMic,
            onSeat: onSeat,
            leaveSeat: leaveSeat,
            billingOnly: billingOnly,
          );
          return _sessionFromMap(map, roomId);
        };
  }

  static bool get isConnected => _e.isConnected;
  static bool get canPublishNow => _e.canPublishNow;
  static bool get hasMicPublication => _e.hasMicPublication;
  static bool get hasLiveMicTrack => _e.hasLiveMicTrack;
  static bool get speakerOn => _e.speakerOn;
  static double get remoteVolume => _e.remoteVolume;
  static bool get remoteAudioMuted => _e.remoteAudioMuted;
  static String? get connectedSkLiveRoomId => _e.connectedAppRoomId;
  static String? get cachedOrbitRoomId => _cachedOrbitRoomId;

  static bool get lastMicFailWasPermission => _lastMicFailWasPermission;

  static bool isLiveForRoom(String roomId) => _e.isLiveForRoom(roomId);

  static void setTransportLostHandler(void Function(String reason)? handler) =>
      _e.setTransportLostHandler(handler);

  static void setSpeakerLevelsHandler(
    void Function(Map<String, double> levels)? handler,
  ) => _e.setSpeakerLevelsHandler(handler);

  static void prefetchSession(String roomId) {
    _wireFetcher();
    _e.prefetchSession(roomId);
  }

  static void claimPrefetch(String roomId) => _e.claimPrefetch(roomId);

  static void clearPrefetch({String? roomId}) =>
      _e.clearPrefetch(roomId: roomId);

  static Future<Map<String, dynamic>?> fetchSessionCached({
    required String roomId,
    required bool openMic,
    bool onSeat = false,
    bool billingOnly = false,
    bool leaveSeat = false,
  }) async {
    _wireFetcher();
    if (billingOnly || leaveSeat) {
      final map = await fetchSession(
        roomId: roomId,
        openMic: openMic,
        onSeat: onSeat,
        billingOnly: billingOnly,
        leaveSeat: leaveSeat,
      );
      return map;
    }
    final session = await _e.fetchSessionCached(
      roomId: roomId,
      openMic: openMic,
      onSeat: onSeat,
    );
    return _toSkMap(session);
  }

  static Future<bool> connect({
    required String livekitUrl,
    required String token,
    bool forceReconnect = false,
    String? skLiveRoomId,
  }) {
    return AppTelemetry.traceAsync('voice_join', () async {
      _wireFetcher();
      if (forceReconnect) {
        try {
          await _e.logoutRoom();
        } catch (e) {
          debugPrint('[ORBIT] forceReconnect logout: $e');
        }
      }
      final orbitId =
          (_cachedSkLiveRoomId == skLiveRoomId ? _cachedOrbitRoomId : null) ??
          skLiveRoomId ??
          _cachedOrbitRoomId ??
          '';
      try {
        await _e.loginRoom(
          OrbitVoiceSession(
            token: token,
            livekitUrl: livekitUrl,
            livekitRoom: orbitId,
            orbitRoomId: orbitId,
            canPublish: false,
            role: 'listener',
            appRoomId: skLiveRoomId ?? _cachedSkLiveRoomId,
          ),
        );

        await ensureDenoisePrefLoaded();
        await _e.setNoiseCancellation(_denoisePrefEnabled);
        _logDenoiseState();
        return _e.isConnected;
      } catch (e) {
        debugPrint('[ORBIT] connect failed: $e');
        return false;
      }
    });
  }

  static Future<void> disconnect() => _e.logoutRoom();

  static bool get noiseCancellationEnabled => _e.noiseCancellationEnabled;

  static bool get noiseCancellationPrefEnabled => _denoisePrefEnabled;

  static Future<void> ensureDenoisePrefLoaded() async {
    if (_denoisePrefHydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _denoisePrefEnabled = prefs.getBool(_denoisePrefKey) ?? true;
    } catch (e) {
      debugPrint('[ORBIT] denoise pref load: $e');
      _denoisePrefEnabled = true;
    }
    _denoisePrefHydrated = true;
  }

  static Future<void> setNoiseCancellation(bool enabled) async {
    _denoisePrefEnabled = enabled;
    _denoisePrefHydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_denoisePrefKey, enabled);
    } catch (e) {
      debugPrint('[ORBIT] denoise pref save: $e');
    }
    await _e.setNoiseCancellation(enabled);
    _logDenoiseState();
  }

  static void _logDenoiseState() {
    if (!kDebugMode) return;
    Future<void> sample(String when) async {
      final stats = await _e.denoise?.stats();
      debugPrint(
        '[ORBIT] denoise@$when ${stats ?? 'stage not attached'} '
        'nc=$noiseCancellationEnabled mode=${_e.roomAudioMode.name} '
        'dartAttached=${_e.denoise?.isAttached}',
      );
    }

    unawaited(Future.delayed(const Duration(seconds: 6), () => sample('t+6s')));
    unawaited(
      Future.delayed(const Duration(seconds: 14), () => sample('t+14s')),
    );
  }

  static Future<void> setRoomAudioMode(OrbitRoomAudioMode mode) =>
      _e.setRoomAudioMode(mode);

  static Future<void> applyRoomTopicAudioMode(String? topic) {
    return _e.setRoomAudioMode(OrbitRoomAudioMode.talk);
  }

  static void setMicIntent(bool openMic) => _e.setMicIntent(openMic);

  static Future<bool> setMicEnabled(bool enabled) async {
    if (enabled) _lastMicFailWasPermission = false;
    final ok = await _e.setMicEnabled(enabled);
    if (enabled && !ok && !_e.canPublishNow) {
      _lastMicFailWasPermission = true;
      debugPrint(
        '[ORBIT] setMicEnabled(true) failed: no publish permission on this '
        'token — needs regrant',
      );
    }
    return ok;
  }

  static Future<void> primeMicIfNeeded() => _e.primeMicIfNeeded();

  static void schedulePrime() => _e.schedulePrime();

  static Future<bool> waitForPublishPermission({
    Duration timeout = const Duration(milliseconds: 2500),
  }) => _e.waitForPublishPermission(timeout: timeout);

  static Future<void> setRemoteVolume(double volume) =>
      _e.setRemoteVolume(volume);

  static Future<void> setRemoteAudioMuted(bool muted) =>
      _e.setRemoteAudioMuted(muted);

  static Future<void> setSpeakerOn(bool on) => _e.setSpeakerOn(on);

  static Future<void> reassertRemoteHearing(String reason) =>
      _e.reassertRemoteHearing(reason);

  static void silenceForExit({required String roomId}) =>
      _e.silenceForExit(roomId: roomId);

  static Future<void> stopLocalAudioForExit({required String roomId}) =>
      _e.stopLocalAudioForExit(roomId: roomId);

  static Future<void> stopPublishAndLeave({required String roomId}) {
    _wireFetcher();
    return _e.stopPublishAndLeave(roomId: roomId);
  }

  static Future<void> stopPublishAndDisconnect({String? roomId}) {
    final id = roomId ?? _cachedSkLiveRoomId;
    if (id != null && id.isNotEmpty) {
      return stopPublishAndLeave(roomId: id);
    }
    return disconnect();
  }

  static OrbitVoiceSession? _sessionFromMap(
    Map<String, dynamic>? map,
    String roomId,
  ) {
    if (map == null || map['error'] != null) return null;
    final token = map['token']?.toString() ?? '';
    final url = map['livekit_url']?.toString() ?? '';
    if (token.isEmpty || url.isEmpty) return null;
    return OrbitVoiceSession(
      token: token,
      livekitUrl: url,
      livekitRoom: map['livekit_room']?.toString() ?? '',
      orbitRoomId: map['orbit_room_id']?.toString() ?? '',
      canPublish: map['can_publish'] == true,
      role: map['role']?.toString() ?? 'listener',
      onSeat: map['on_seat'] as bool?,
      appRoomId: roomId,
    );
  }

  static Map<String, dynamic>? _toSkMap(OrbitVoiceSession? s) {
    if (s == null) return null;
    return <String, dynamic>{
      'token': s.token,
      'livekit_url': s.livekitUrl,
      'livekit_room': s.livekitRoom,
      'orbit_room_id': s.orbitRoomId,
      'can_publish': s.canPublish,
      'role': s.role,
      if (s.onSeat != null) 'on_seat': s.onSeat,
    };
  }

  static Future<Map<String, dynamic>?> fetchSession({
    required String roomId,
    required bool openMic,
    bool onSeat = false,
    bool billingOnly = false,
    bool leaveSeat = false,
  }) async {
    final body = <String, dynamic>{
      'room_id': roomId,
      'open_mic': openMic,
      'on_seat': onSeat,
      if (billingOnly) 'billing_only': true,
      if (leaveSeat) 'leave_seat': true,
      if (_cachedOrbitRoomId != null && _cachedSkLiveRoomId == roomId)
        'orbit_room_id': _cachedOrbitRoomId,
    };

    Map<String, dynamic>? map;
    if (AppConstants.useRealtimeGateway &&
        RoomRealtimeSocket.instance.isConnected) {
      try {
        final gw = await RoomRealtimeSocket.instance.voiceToken(body);
        if (gw != null) {
          final err = gw['error']?.toString();
          final fallback =
              err == 'offline' ||
              err == 'unauthorized' ||
              err == 'timeout' ||
              err == 'orbit_not_configured' ||
              err == 'orbit_join_failed' ||
              err == 'orbit_create_failed' ||
              err == 'orbit_resolve_failed' ||
              err == 'orbit_token_failed';
          if (fallback && err != 'offline' && err != 'timeout') {
            _cachedOrbitRoomId = null;
            _cachedSkLiveRoomId = null;
            body.remove('orbit_room_id');
          }
          if (gw['ok'] != false && err == null) {
            map = Map<String, dynamic>.from(gw);
            map.remove('ok');
            debugPrint('[ORBIT] gateway voice:token ok room=$roomId');
          } else if (err != null && !fallback) {
            debugPrint('[ORBIT] gateway voice:token error=$err');
            map = Map<String, dynamic>.from(gw);
            map.remove('ok');
          } else {
            debugPrint('[ORBIT] gateway voice:token fallback err=$err');
          }
        }
      } catch (e) {
        debugPrint('[ORBIT] gateway voice:token failed: $e');
      }
    }

    if (map == null) {
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'orbit-voice-session',
          body: body,
        );
        final data = res.data;
        if (data is! Map) {
          debugPrint('[ORBIT] session bad payload: ${res.data}');
          return null;
        }
        map = Map<String, dynamic>.from(data);
      } catch (e) {
        debugPrint('[ORBIT] edge orbit-voice-session failed: $e');
        return null;
      }
    }

    final oid = map['orbit_room_id']?.toString();
    if (oid != null && oid.isNotEmpty) {
      final liveElsewhere =
          leaveSeat &&
          _e.connectedAppRoomId != null &&
          _e.connectedAppRoomId != roomId;
      if (!liveElsewhere) {
        _cachedOrbitRoomId = oid;
        _cachedSkLiveRoomId = roomId;
      }
    }
    final timings = map['timings'];
    if (timings != null) {
      debugPrint(
        '[ORBIT] timings $timings billingOnly=$billingOnly leaveSeat=$leaveSeat',
      );
    }
    return map;
  }
}
