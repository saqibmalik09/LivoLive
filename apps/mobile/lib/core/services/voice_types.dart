/// Voice session types, owned by this app.
///
/// These were previously supplied by the vendor's `orbit_voice` package. That
/// package was never delivered to us, which blocked every Android build, and
/// the platform has since moved to direct LiveKit anyway — so the handful of
/// plain data types it provided now live here and the dependency is gone.
///
/// The `Orbit*` names are kept deliberately: they are referenced throughout
/// `orbit_voice_session_service.dart`, and renaming them during a live incident
/// would add churn for no functional gain. They describe this app's own voice
/// session now, not the vendor's SDK.
library voice_types;

/// How the room drives the audio session.
enum OrbitRoomAudioMode { talk, music }

/// One voice session: where to connect, with what token, and what it allows.
class OrbitVoiceSession {
  const OrbitVoiceSession({
    required this.token,
    required this.livekitUrl,
    required this.livekitRoom,
    required this.orbitRoomId,
    required this.canPublish,
    required this.role,
    this.onSeat,
    this.appRoomId,
  });

  final String token;
  final String livekitUrl;
  final String livekitRoom;

  /// Server-side room identifier. Same value as [livekitRoom] on the LiveKit
  /// backend; kept separate because the session cache is keyed on it.
  final String orbitRoomId;

  final bool canPublish;
  final String role;
  final bool? onSeat;
  final String? appRoomId;
}

/// Fetches a session from the backend (gateway first, edge function fallback).
typedef OrbitSessionFetcher =
    Future<OrbitVoiceSession?> Function({
      required String roomId,
      required bool openMic,
      bool onSeat,
      bool leaveSeat,
      bool billingOnly,
    });

/// Noise-suppression stage.
///
/// The vendor's DeepFilterNet stage came from their native library and is not
/// available to us. The LiveKit path uses WebRTC's own echo cancellation, noise
/// suppression and auto gain control instead, which need no stage object — so
/// this is reported as absent and the type exists only to keep the engine
/// surface stable.
class OrbitDenoiseStage {
  bool get isAttached => false;
  Future<String?> stats() async => null;
}
