import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:orbit_voice/orbit_voice.dart';

import 'voice_engine.dart';

/// Direct LiveKit engine — used when system_settings.voice_backend = 'livekit'.
///
/// The backend (gateway or the orbit-voice-session edge function) mints the
/// token and names the room; this class only joins and drives audio.
///
/// Difference from the Orbit path: there is **no DeepFilterNet denoise**. That
/// lives in the vendor's native library. Noise suppression here is whatever
/// WebRTC provides, so [setNoiseCancellation] records the preference but cannot
/// apply the studio filter.
class LiveKitVoiceEngine implements VoiceEngine {
  LiveKitVoiceEngine._();
  static final LiveKitVoiceEngine instance = LiveKitVoiceEngine._();

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _events;
  String? _appRoomId;
  bool _speakerOn = true;
  bool _remoteMuted = false;
  double _remoteVolume = 1.0;
  bool _micIntent = false;
  bool _denoisePref = false;
  OrbitRoomAudioMode _audioMode = OrbitRoomAudioMode.talk;

  void Function(String reason)? _onTransportLost;
  void Function(Map<String, double> levels)? _onSpeakerLevels;

  @override
  OrbitSessionFetcher? sessionFetcher;

  // ---------------------------------------------------------------- state

  @override
  bool get isConnected => _room?.connectionState == lk.ConnectionState.connected;

  @override
  bool get canPublishNow =>
      _room?.localParticipant?.permissions.canPublish ?? false;

  @override
  bool get hasMicPublication =>
      (_room?.localParticipant?.audioTrackPublications.isNotEmpty) ?? false;

  @override
  bool get hasLiveMicTrack {
    final pub = _room?.localParticipant?.audioTrackPublications.firstOrNull;
    return pub != null && pub.track != null && !pub.muted;
  }

  @override
  bool get speakerOn => _speakerOn;
  @override
  double get remoteVolume => _remoteVolume;
  @override
  bool get remoteAudioMuted => _remoteMuted;
  @override
  String? get connectedAppRoomId => _appRoomId;
  @override
  bool get noiseCancellationEnabled => _denoisePref;
  @override
  OrbitRoomAudioMode get roomAudioMode => _audioMode;

  /// Always null — DeepFilterNet is not available on this path.
  @override
  OrbitDenoiseStage? get denoise => null;

  @override
  bool isLiveForRoom(String roomId) => isConnected && _appRoomId == roomId;

  // ------------------------------------------------------------- handlers

  @override
  void setTransportLostHandler(void Function(String reason)? handler) =>
      _onTransportLost = handler;

  @override
  void setSpeakerLevelsHandler(void Function(Map<String, double> levels)? h) =>
      _onSpeakerLevels = h;

  // Prefetch is an Orbit-side optimisation; joining here is fast enough.
  @override
  void prefetchSession(String roomId) {}
  @override
  void claimPrefetch(String roomId) {}
  @override
  void clearPrefetch({String? roomId}) {}

  @override
  Future<OrbitVoiceSession?> fetchSessionCached({
    required String roomId,
    required bool openMic,
    bool onSeat = false,
  }) async {
    final fetcher = sessionFetcher;
    if (fetcher == null) return null;
    return fetcher(roomId: roomId, openMic: openMic, onSeat: onSeat);
  }

  // ------------------------------------------------------------ lifecycle

  @override
  Future<void> loginRoom(OrbitVoiceSession session) async {
    if (session.token.isEmpty || session.livekitUrl.isEmpty) {
      throw StateError('livekit: session is missing token or url');
    }
    await logoutRoom();

    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      ),
    );

    final events = room.createListener();
    events
      ..on<lk.RoomDisconnectedEvent>((e) {
        final reason = e.reason?.name ?? 'disconnected';
        debugPrint('[LK] disconnected: $reason');
        _onTransportLost?.call(reason);
      })
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        final handler = _onSpeakerLevels;
        if (handler == null) return;
        handler(<String, double>{
          for (final p in e.speakers) p.identity: p.audioLevel,
        });
      });

    _room = room;
    _events = events;
    _appRoomId = session.appRoomId ?? session.orbitRoomId;

    await room.connect(session.livekitUrl, session.token);
    await lk.Hardware.instance.setSpeakerphoneOn(_speakerOn);

    // The token's grant is authoritative; only publish if the server allowed it.
    if (_micIntent && canPublishNow) {
      await setMicEnabled(true);
    }
    debugPrint(
      '[LK] joined room=${session.livekitRoom} publish=$canPublishNow',
    );
  }

  @override
  Future<void> logoutRoom() async {
    final room = _room;
    final events = _events;
    _room = null;
    _events = null;
    _appRoomId = null;
    try {
      await events?.dispose();
      await room?.disconnect();
      await room?.dispose();
    } catch (e) {
      debugPrint('[LK] logout: $e');
    }
  }

  // ----------------------------------------------------------------- audio

  /// Records the preference only — the studio denoise filter is unavailable here.
  @override
  Future<void> setNoiseCancellation(bool enabled) async {
    _denoisePref = enabled;
  }

  @override
  Future<void> setRoomAudioMode(OrbitRoomAudioMode mode) async {
    _audioMode = mode;
  }

  @override
  void setMicIntent(bool openMic) => _micIntent = openMic;

  @override
  Future<bool> setMicEnabled(bool enabled) async {
    final local = _room?.localParticipant;
    if (local == null) return false;
    if (enabled && !canPublishNow) {
      debugPrint('[LK] mic denied — token grant has canPublish=false');
      return false;
    }
    try {
      await local.setMicrophoneEnabled(enabled);
      return hasLiveMicTrack == enabled;
    } catch (e) {
      debugPrint('[LK] setMicEnabled($enabled): $e');
      return false;
    }
  }

  @override
  Future<void> primeMicIfNeeded() async {}
  @override
  void schedulePrime() {}

  @override
  Future<bool> waitForPublishPermission({Duration? timeout}) async {
    final deadline = DateTime.now().add(timeout ?? const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (canPublishNow) return true;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return canPublishNow;
  }

  /// LiveKit 2.11 exposes no per-track volume, so anything at or below zero is
  /// treated as a mute and anything above it as unmuted.
  @override
  Future<void> setRemoteVolume(double volume) async {
    _remoteVolume = volume;
    await setRemoteAudioMuted(volume <= 0.0);
  }

  @override
  Future<void> setRemoteAudioMuted(bool muted) async {
    _remoteMuted = muted;
    final room = _room;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      for (final pub in participant.audioTrackPublications) {
        try {
          muted ? await pub.track?.disable() : await pub.track?.enable();
        } catch (e) {
          debugPrint('[LK] remote mute ${participant.identity}: $e');
        }
      }
    }
  }

  @override
  Future<void> setSpeakerOn(bool on) async {
    _speakerOn = on;
    try {
      await lk.Hardware.instance.setSpeakerphoneOn(on);
    } catch (e) {
      debugPrint('[LK] setSpeakerOn($on): $e');
    }
  }

  @override
  Future<void> reassertRemoteHearing(String reason) async {
    if (!isConnected) return;
    await setRemoteAudioMuted(_remoteMuted);
    await lk.Hardware.instance.setSpeakerphoneOn(_speakerOn);
  }

  // ------------------------------------------------------------------ exit

  @override
  void silenceForExit({required String roomId}) {
    if (_appRoomId != roomId) return;
    unawaited(setRemoteAudioMuted(true));
  }

  @override
  Future<void> stopLocalAudioForExit({required String roomId}) async {
    if (_appRoomId != roomId) return;
    await setMicEnabled(false);
  }

  @override
  Future<void> stopPublishAndLeave({required String roomId}) async {
    if (_appRoomId != roomId) return;
    await setMicEnabled(false);
    await logoutRoom();
  }
}
