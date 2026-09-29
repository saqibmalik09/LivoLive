import 'package:sk_live/core/services/voice_types.dart';

/// The engine surface `OrbitVoiceSessionService` depends on.
///
/// `LiveKitVoiceEngine` is the only implementation. The interface is kept so the
/// ~134 call sites across the app stay decoupled from the engine, and so a second
/// backend can be added later without touching them.
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
