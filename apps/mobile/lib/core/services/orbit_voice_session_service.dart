import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sk_live/core/services/voice_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/services/livekit_voice_engine.dart';
import 'package:sk_live/core/services/voice_engine.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrbitVoiceSessionService {
  OrbitVoiceSessionService._();

  /// Direct LiveKit is the only voice engine now that the vendor package is gone.
  static VoiceEngine get _e => LiveKitVoiceEngine.instance;

  /// Retained for callers that ask; always true.
  static bool get isLiveKitBackend => true;

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
    // The vendor's OrbitAudioBootstrap used to prime WebRTC's audio attributes
    // here. livekit_client configures the audio session itself on connect, and
    // the engine sets the speaker route immediately afterwards, so there is
    // nothing left to prime ahead of time.
  }

  static void _wireFetcher() {
    if (_fetcherWired) return;
    _fetcherWired = true;
    LiveKitVoiceEngine.instance.sessionFetcher =
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

  // Listener session minted on the room tap, and the LiveKit connect started
  // from it, so neither waits for the room screen to build, the profile, or
  // the room:join ack. The screen's fetchSession / connect pick them up.
  static Future<Map<String, dynamic>?>? _earlySession;
  static String? _earlyRoomId;
  static Stopwatch? _earlyWatch;
  static Future<bool>? _preconnect;
  static String? _preconnectRoomId;
  static String? _preconnectToken;
  static bool _preconnectCancelled = false;
  static const _earlySessionMaxAge = Duration(seconds: 30);

  static void prefetchSession(String roomId) {
    _wireFetcher();
    _e.prefetchSession(roomId);
    if (roomId.isEmpty || _e.isLiveForRoom(roomId)) return;
    if (_earlyRoomId == roomId && _earlySession != null) return;
    _earlyRoomId = roomId;
    final watch = Stopwatch()..start();
    _earlyWatch = watch;
    final session = _mintEarlySession(roomId);
    _earlySession = session;
    _preconnectRoomId = roomId;
    _preconnectToken = null;
    _preconnectCancelled = false;
    _preconnect = session.then((map) async {
      if (_preconnectRoomId != roomId || _preconnectCancelled) return false;
      final token = map?['token']?.toString() ?? '';
      final url = map?['livekit_url']?.toString() ?? '';
      if (map == null || map['error'] != null || token.isEmpty || url.isEmpty) {
        return false;
      }
      debugPrint('[VOICE-OPEN] token ms=${watch.elapsedMilliseconds}');
      _preconnectToken = token;
      // A mic intent left over from the previous room must not open the mic
      // here; the room screen turns it on itself once it knows the seat.
      _e.setMicIntent(false);
      final ok = await _connectNow(
        livekitUrl: url,
        token: token,
        skLiveRoomId: roomId,
        canPublish: map['can_publish'] == true,
      );
      final ms = watch.elapsedMilliseconds;
      debugPrint('[VOICE-OPEN] connected=$ok ms=$ms');
      if (ms > 1500) AppTelemetry.log('SLOW voice_open ${ms}ms');
      if (_preconnectCancelled && _e.connectedAppRoomId == roomId) {
        await _e.logoutRoom();
        return false;
      }
      return ok;
    }, onError: (Object e) {
      debugPrint('[VOICE-OPEN] preconnect failed: $e');
      return false;
    });
  }

  static Future<Map<String, dynamic>?> _mintEarlySession(String roomId) async {
    final socket = RoomRealtimeSocket.instance;
    if (AppConstants.useRealtimeGateway && !socket.isConnected) {
      // Waiting a moment for the socket is far cheaper than the edge-function
      // fallback fetchSession takes when it finds the socket down.
      try {
        await socket.ensureConnected().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    return _fetchSessionDirect(roomId: roomId, openMic: false, onSeat: false);
  }

  /// The tap-time session, once, if it is still fresh.
  static Future<Map<String, dynamic>?> _takeEarlySession(String roomId) async {
    if (_earlyRoomId != roomId) return null;
    final session = _earlySession;
    final age = _earlyWatch?.elapsed;
    _earlySession = null;
    _earlyRoomId = null;
    if (session == null || age == null || age > _earlySessionMaxAge) {
      return null;
    }
    try {
      return await session.timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  static void _cancelEarly(String? roomId) {
    if (roomId != null && _earlyRoomId != null && _earlyRoomId != roomId) {
      return;
    }
    _earlySession = null;
    _earlyRoomId = null;
    if (roomId == null || _preconnectRoomId == roomId) {
      _preconnectCancelled = true;
      _preconnect = null;
      _preconnectRoomId = null;
      _preconnectToken = null;
    }
  }

  static void claimPrefetch(String roomId) => _e.claimPrefetch(roomId);

  static void clearPrefetch({String? roomId}) {
    _cancelEarly(roomId);
    _e.clearPrefetch(roomId: roomId);
  }

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

  /// [canPublish] must be the grant from the token that was just minted. The
  /// engine picks the audio session type from it once, at connect, so a host
  /// gets call-mode capture and a listener gets media-volume playback without
  /// anything being flipped mid-room.
  static Future<bool> connect({
    required String livekitUrl,
    required String token,
    bool forceReconnect = false,
    String? skLiveRoomId,
    bool canPublish = false,
  }) async {
    final pre = _preconnect;
    if (pre != null) {
      final sameSession =
          _preconnectRoomId == skLiveRoomId && _preconnectToken == token;
      if (sameSession && !forceReconnect) {
        _preconnect = null;
        _preconnectRoomId = null;
        _preconnectToken = null;
        // Already connecting (or connected) on this exact token since the tap.
        if (await pre) return true;
      } else {
        // Let the tap-time connect settle first: two logins at once tear each
        // other's room down.
        try {
          await pre.timeout(const Duration(seconds: 4));
        } catch (_) {}
        _preconnect = null;
        _preconnectRoomId = null;
        _preconnectToken = null;
        if (!forceReconnect && isLiveForRoom(skLiveRoomId ?? '')) {
          // Different token, same room, already live: the room screen asked
          // for an identical listener session; reconnecting buys nothing.
          if (!canPublish || canPublishNow) return true;
        }
      }
    }
    return _connectNow(
      livekitUrl: livekitUrl,
      token: token,
      forceReconnect: forceReconnect,
      skLiveRoomId: skLiveRoomId,
      canPublish: canPublish,
    );
  }

  static Future<bool> _connectNow({
    required String livekitUrl,
    required String token,
    bool forceReconnect = false,
    String? skLiveRoomId,
    bool canPublish = false,
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
            canPublish: canPublish,
            role: canPublish ? 'speaker' : 'listener',
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

  static Future<void> disconnect() {
    _cancelEarly(null);
    return _e.logoutRoom();
  }

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

  /// Resolves once voice is connected to [roomId] (true), or false after
  /// [timeout]. A seat tapped right after entering lands while the connect is
  /// still running; the seat's voice work waits for it instead of skipping.
  static Future<bool> waitUntilLive(
    String roomId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isLiveForRoom(roomId)) return true;
    final deadline = DateTime.now().add(timeout);
    final pre = _preconnect;
    if (pre != null && _preconnectRoomId == roomId) {
      try {
        await pre.timeout(timeout);
      } catch (_) {}
    }
    while (!isLiveForRoom(roomId) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return isLiveForRoom(roomId);
  }

  // Bumped whenever a pending prepare should be dropped (dialog dismissed,
  // claim failed), so a prepare still waiting on the connect does not open
  // the mic afterwards for a seat nobody took.
  static int _prepareGen = 0;

  /// Start connecting the publisher transport before the first publish.
  static void warmPublisher() =>
      unawaited(LiveKitVoiceEngine.instance.warmPublisher());

  static void _whenLive(String? roomId, void Function() run) {
    final id = roomId ?? connectedSkLiveRoomId;
    if (id == null || id.isEmpty || isLiveForRoom(id)) {
      run();
      return;
    }
    final gen = _prepareGen;
    unawaited(() async {
      if (!await waitUntilLive(id)) return;
      if (gen != _prepareGen) return;
      run();
    }());
  }

  /// Open the microphone before the publish grant arrives. Needs the OS mic
  /// permission to be granted already.
  static void precaptureMic() =>
      unawaited(LiveKitVoiceEngine.instance.precaptureMic());

  /// Connect the publisher, open the mic and publish it muted as soon as the
  /// gateway's early grant lands, so taking the seat is just an unmute. Needs
  /// the OS mic permission already.
  static void prepareToSpeak({String? roomId}) => _whenLive(
    roomId,
    () => unawaited(LiveKitVoiceEngine.instance.prepareToSpeak()),
  );

  /// [warmPublisher] for a seat tap that may land before voice is connected.
  static void warmPublisherFor(String roomId) => _whenLive(roomId, warmPublisher);

  /// Remove the microphone publication (seat left). The gateway revokes
  /// publish, so the connection stays up.
  static Future<void> unpublishMic() =>
      LiveKitVoiceEngine.instance.unpublishMic();

  /// Seat state for the speak permission. See LiveKitVoiceEngine.canPublishNow.
  static void setSeatPublishAllowed(bool onSeat, {String? roomId}) => LiveKitVoiceEngine
      .instance
      .setSeatPublishAllowed(onSeat, roomId: roomId);
  static void markSitIntent({String? roomId}) =>
      LiveKitVoiceEngine.instance.markSitIntent(roomId: roomId);
  static void clearSitIntent() {
    _prepareGen++;
    LiveKitVoiceEngine.instance.clearSitIntent();
  }

  /// Release whatever [prepareToSpeak] set up and was not used.
  static void discardPrecapturedMic() {
    _prepareGen++;
    unawaited(LiveKitVoiceEngine.instance.discardPrecapturedMic());
  }

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
    _cancelEarly(roomId);
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
    if (!billingOnly &&
        !leaveSeat &&
        !RoomRealtimeSocket.instance.hasVoiceSession(roomId)) {
      final early = await _takeEarlySession(roomId);
      if (early != null && early['error'] == null) {
        final grantsPublish = early['can_publish'] == true;
        if (grantsPublish || !(openMic || onSeat)) {
          debugPrint(
            '[ORBIT] using tap-time session room=$roomId '
            'publish=$grantsPublish',
          );
          return early;
        }
      }
    }
    return _fetchSessionDirect(
      roomId: roomId,
      openMic: openMic,
      onSeat: onSeat,
      billingOnly: billingOnly,
      leaveSeat: leaveSeat,
    );
  }

  static Future<Map<String, dynamic>?> _fetchSessionDirect({
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

    // The gateway now sends a signed session with the room:join and seat:sit
    // acks. Using it means going live or taking the mic costs no extra round
    // trip at all. A listener token only satisfies a listener request; a
    // publish token satisfies either.
    if (!billingOnly && !leaveSeat) {
      final prefetched = RoomRealtimeSocket.instance.takeVoiceSession(roomId);
      if (prefetched != null) {
        final grantsPublish = prefetched['can_publish'] == true;
        if (grantsPublish || !(openMic || onSeat)) {
          debugPrint(
            '[ORBIT] using prefetched session room=$roomId '
            'publish=$grantsPublish',
          );
          map = prefetched;
        } else {
          debugPrint(
            '[ORBIT] prefetched session is listener-only, minting instead',
          );
        }
      }
    }

    if (map == null &&
        AppConstants.useRealtimeGateway &&
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
