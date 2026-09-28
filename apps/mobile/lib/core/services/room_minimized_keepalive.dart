import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';

class RoomMinimizedKeepAlive {
  RoomMinimizedKeepAlive._();

  static Timer? _timer;
  static String? _roomId;
  static Map<String, dynamic>? _user;
  static int _generation = 0;
  static int? _voiceSeatIndex;
  static bool? _voiceMuted;
  static bool? _voiceOrbitCanPublish;
  static bool? _voiceLocalPublishing;

  static int _orbitHealOwnerToken = 0;
  static int? _myOrbitHealToken;
  static Timer? _orbitHealDebounce;
  static bool _orbitHealInFlight = false;

  static String? get roomId => _roomId;
  static bool get isActive => _roomId != null;
  static int? get voiceSeatIndex => _voiceSeatIndex;
  static bool? get voiceMuted => _voiceMuted;
  static bool? get voiceOrbitCanPublish => _voiceOrbitCanPublish;
  static bool? get voiceLocalPublishing => _voiceLocalPublishing;

  static void saveVoiceState({
    int? seatIndex,
    required bool isMuted,
    required bool orbitCanPublish,
    required bool localPublishing,
  }) {
    _voiceSeatIndex = seatIndex;
    _voiceMuted = isMuted;
    _voiceOrbitCanPublish = orbitCanPublish;
    _voiceLocalPublishing = localPublishing;
    debugPrint(
      '[KeepAlive] voice seat=$seatIndex muted=$isMuted '
      'canPub=$orbitCanPublish pub=$localPublishing',
    );
  }

  static void clearVoiceState() {
    _voiceSeatIndex = null;
    _voiceMuted = null;
    _voiceOrbitCanPublish = null;
    _voiceLocalPublishing = null;
  }

  static void claimOrbitTransportHeal() {
    final token = ++_orbitHealOwnerToken;
    _myOrbitHealToken = token;
    OrbitVoiceSessionService.setTransportLostHandler((reason) {
      if (_myOrbitHealToken != token) return;
      _onOrbitTransportLost(reason);
    });
    debugPrint('[KeepAlive] claimed Orbit transport heal token=$token');
  }

  static void relinquishOrbitHeal() {
    _myOrbitHealToken = null;
    _orbitHealDebounce?.cancel();
    _orbitHealDebounce = null;
  }

  static void releaseOrbitTransportHeal() {
    final mine = _myOrbitHealToken;
    _myOrbitHealToken = null;
    _orbitHealDebounce?.cancel();
    _orbitHealDebounce = null;
    if (mine != null && mine == _orbitHealOwnerToken) {
      OrbitVoiceSessionService.setTransportLostHandler(null);
      debugPrint('[KeepAlive] released Orbit transport heal');
    }
  }

  static void _onOrbitTransportLost(String reason) {
    if (_roomId == null || _voiceSeatIndex == null) return;
    _orbitHealDebounce?.cancel();
    _orbitHealDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_healOrbit(reason));
    });
  }

  static Future<void> _healOrbit(String reason) async {
    if (_orbitHealInFlight) return;
    final roomId = _roomId;
    final seat = _voiceSeatIndex;
    if (roomId == null || seat == null) return;

    final bubbleActive =
        RoomFloatingBubbleService.overlayConfirmedActive ||
        await RoomFloatingBubbleService.isConfirmedActive();
    if (!isActive && !bubbleActive) {
      debugPrint(
        '[KeepAlive] skip Orbit heal ($reason) — no keep-alive/bubble',
      );
      return;
    }

    _orbitHealInFlight = true;
    try {
      final wantMic = _voiceMuted != true;
      debugPrint(
        '[KeepAlive] Orbit heal ($reason) room=$roomId wantMic=$wantMic',
      );

      final session = await OrbitVoiceSessionService.fetchSession(
        roomId: roomId,
        openMic: wantMic,
        onSeat: true,
      );
      if (session == null || session['error'] != null) {
        debugPrint('[KeepAlive] Orbit heal session failed: $session');
        return;
      }

      final token = session['token']?.toString() ?? '';
      final url = session['livekit_url']?.toString() ?? '';
      if (token.isEmpty || url.isEmpty) {
        debugPrint('[KeepAlive] Orbit heal missing token/url');
        return;
      }

      final connected = await OrbitVoiceSessionService.connect(
        livekitUrl: url,
        token: token,
        forceReconnect: true,
        skLiveRoomId: roomId,
      );
      if (!connected) return;

      await OrbitVoiceSessionService.waitForPublishPermission();
      final ok = await OrbitVoiceSessionService.setMicEnabled(wantMic);
      _voiceLocalPublishing = wantMic && ok;
      _voiceOrbitCanPublish =
          session['can_publish'] == true ||
          OrbitVoiceSessionService.canPublishNow;
      debugPrint(
        '[KeepAlive] Orbit heal done mic=$wantMic ok=$ok '
        'canPub=$_voiceOrbitCanPublish',
      );
    } catch (e) {
      debugPrint('[KeepAlive] Orbit heal error: $e');
    } finally {
      _orbitHealInFlight = false;
    }
  }

  static void start({
    required String roomId,
    required Map<String, dynamic> user,
  }) {
    if (!AppConstants.useRealtimeGateway) {
      _roomId = roomId.trim().isEmpty ? null : roomId.trim();
      claimOrbitTransportHeal();
      return;
    }
    final id = roomId.trim();
    if (id.isEmpty) return;

    if (_roomId != null && _roomId != id) {
      debugPrint('[KeepAlive] switch $_roomId -> $id');
    }
    _timer?.cancel();
    _generation += 1;
    final gen = _generation;
    _roomId = id;
    _user = Map<String, dynamic>.from(user);
    _timer = Timer.periodic(const Duration(seconds: 35), (_) {
      unawaited(_beat(gen));
    });
    unawaited(_beat(gen));
    claimOrbitTransportHeal();
    debugPrint('[KeepAlive] started room=$id gen=$gen');
  }

  static void stop() {
    if (_timer == null &&
        _roomId == null &&
        _voiceSeatIndex == null &&
        _myOrbitHealToken == null) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _roomId = null;
    _user = null;
    clearVoiceState();
    _generation += 1;
    releaseOrbitTransportHeal();
    debugPrint('[KeepAlive] stopped');
  }

  static void stopIfRoom(String? roomId) {
    if (roomId == null || roomId.isEmpty) return;
    if (_roomId == roomId) stop();
  }

  static Future<void> _beat(int gen) async {
    if (gen != _generation) return;
    final roomId = _roomId;
    final user = _user;
    if (roomId == null || user == null) return;

    final live = RoomRealtimeSocket.instance.joinedRoomId;
    if (live != roomId) {
      debugPrint('[KeepAlive] auto-stop beat=$roomId live=${live ?? 'none'}');
      stop();
      return;
    }

    try {
      await RoomRealtimeSocket.instance.heartbeat(roomId: roomId, user: user);
    } catch (e) {
      debugPrint('[KeepAlive] heartbeat failed: $e');
    }
  }

  static Map<String, dynamic> userPayload({Map<String, dynamic>? profile}) {
    final authId = Supabase.instance.client.auth.currentUser?.id;
    return {
      'id': profile?['id'] ?? authId,
      'username': profile?['username'],
      'avatar_url': profile?['avatar_url'],
    };
  }
}
