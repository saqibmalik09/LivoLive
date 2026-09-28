import 'package:orbit_voice/orbit_voice.dart';

/// The engine surface `OrbitVoiceSessionService` depends on.
///
/// Two implementations exist: [OrbitEngineAdapter] (the vendor's Orbit/LiveKit
/// stack, with DeepFilterNet denoise) and `LiveKitVoiceEngine` (direct LiveKit,
/// no middleman). Declaring this interface means the ~134 call sites across the
/// app keep working untouched — only which engine backs them changes.
abstract class VoiceEngine {
  set sessionFetcher(OrbitSessionFetcher? fetcher);

  bool get isConnected;
  bool get canPublishNow;
  bool get hasMicPublication;
  bool get hasLiveMicTrack;
  bool get speakerOn;
  double get remoteVolume;
  bool get remoteAudioMuted;
  String? get connectedAppRoomId;
  bool get noiseCancellationEnabled;
  OrbitRoomAudioMode get roomAudioMode;
  OrbitDenoiseStage? get denoise;

  bool isLiveForRoom(String roomId);

  void setTransportLostHandler(void Function(String reason)? handler);
  void setSpeakerLevelsHandler(void Function(Map<String, double> levels)? h);

  void prefetchSession(String roomId);
  void claimPrefetch(String roomId);
  void clearPrefetch({String? roomId});

  Future<OrbitVoiceSession?> fetchSessionCached({
    required String roomId,
    required bool openMic,
    bool onSeat,
  });

  Future<void> loginRoom(OrbitVoiceSession session);
  Future<void> logoutRoom();

  Future<void> setNoiseCancellation(bool enabled);
  Future<void> setRoomAudioMode(OrbitRoomAudioMode mode);

  void setMicIntent(bool openMic);
  Future<bool> setMicEnabled(bool enabled);
  Future<void> primeMicIfNeeded();
  void schedulePrime();
  Future<bool> waitForPublishPermission({Duration? timeout});

  Future<void> setRemoteVolume(double volume);
  Future<void> setRemoteAudioMuted(bool muted);
  Future<void> setSpeakerOn(bool on);
  Future<void> reassertRemoteHearing(String reason);

  void silenceForExit({required String roomId});
  Future<void> stopLocalAudioForExit({required String roomId});
  Future<void> stopPublishAndLeave({required String roomId});
}

/// Forwards everything to the vendor's [OrbitEngine] singleton.
class OrbitEngineAdapter implements VoiceEngine {
  OrbitEngineAdapter._();
  static final OrbitEngineAdapter instance = OrbitEngineAdapter._();
  final OrbitEngine _e = OrbitEngine.instance;

  @override
  set sessionFetcher(OrbitSessionFetcher? fetcher) => _e.sessionFetcher = fetcher;

  @override
  bool get isConnected => _e.isConnected;
  @override
  bool get canPublishNow => _e.canPublishNow;
  @override
  bool get hasMicPublication => _e.hasMicPublication;
  @override
  bool get hasLiveMicTrack => _e.hasLiveMicTrack;
  @override
  bool get speakerOn => _e.speakerOn;
  @override
  double get remoteVolume => _e.remoteVolume;
  @override
  bool get remoteAudioMuted => _e.remoteAudioMuted;
  @override
  String? get connectedAppRoomId => _e.connectedAppRoomId;
  @override
  bool get noiseCancellationEnabled => _e.noiseCancellationEnabled;
  @override
  OrbitRoomAudioMode get roomAudioMode => _e.roomAudioMode;
  @override
  OrbitDenoiseStage? get denoise => _e.denoise;

  @override
  bool isLiveForRoom(String roomId) => _e.isLiveForRoom(roomId);
  @override
  void setTransportLostHandler(void Function(String reason)? handler) =>
      _e.setTransportLostHandler(handler);
  @override
  void setSpeakerLevelsHandler(void Function(Map<String, double> levels)? h) =>
      _e.setSpeakerLevelsHandler(h);
  @override
  void prefetchSession(String roomId) => _e.prefetchSession(roomId);
  @override
  void claimPrefetch(String roomId) => _e.claimPrefetch(roomId);
  @override
  void clearPrefetch({String? roomId}) => _e.clearPrefetch(roomId: roomId);
  @override
  Future<OrbitVoiceSession?> fetchSessionCached({
    required String roomId,
    required bool openMic,
    bool onSeat = false,
  }) => _e.fetchSessionCached(roomId: roomId, openMic: openMic, onSeat: onSeat);
  @override
  Future<void> loginRoom(OrbitVoiceSession session) => _e.loginRoom(session);
  @override
  Future<void> logoutRoom() => _e.logoutRoom();
  @override
  Future<void> setNoiseCancellation(bool enabled) => _e.setNoiseCancellation(enabled);
  @override
  Future<void> setRoomAudioMode(OrbitRoomAudioMode mode) => _e.setRoomAudioMode(mode);
  @override
  void setMicIntent(bool openMic) => _e.setMicIntent(openMic);
  @override
  Future<bool> setMicEnabled(bool enabled) => _e.setMicEnabled(enabled);
  @override
  Future<void> primeMicIfNeeded() => _e.primeMicIfNeeded();
  @override
  void schedulePrime() => _e.schedulePrime();
  @override
  Future<bool> waitForPublishPermission({Duration? timeout}) =>
      _e.waitForPublishPermission(timeout: timeout);
  @override
  Future<void> setRemoteVolume(double volume) => _e.setRemoteVolume(volume);
  @override
  Future<void> setRemoteAudioMuted(bool muted) => _e.setRemoteAudioMuted(muted);
  @override
  Future<void> setSpeakerOn(bool on) => _e.setSpeakerOn(on);
  @override
  Future<void> reassertRemoteHearing(String reason) => _e.reassertRemoteHearing(reason);
  @override
  void silenceForExit({required String roomId}) => _e.silenceForExit(roomId: roomId);
  @override
  Future<void> stopLocalAudioForExit({required String roomId}) =>
      _e.stopLocalAudioForExit(roomId: roomId);
  @override
  Future<void> stopPublishAndLeave({required String roomId}) =>
      _e.stopPublishAndLeave(roomId: roomId);
}
