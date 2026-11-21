import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:sk_live/core/services/voice_types.dart';

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

  /// Plugging a headset in **during** a call used to change nothing: the route
  /// was only re-evaluated on join, on an audio-session switch, and when the
  /// speaker button was pressed. Whatever was decided at join time — with no
  /// headset present that is a *forced* speaker — stayed selected, so the
  /// audio kept coming out of the loudspeaker and never reached the headset.
  ///
  /// Watch the device list instead, so connecting or removing a headset
  /// re-runs the same routing decision immediately.
  StreamSubscription<List<lk.MediaDevice>>? _deviceChangeSub;

  /// Device-change events arrive in bursts while a headset settles (several
  /// within a few hundred ms), and each re-assert does two routing calls with
  /// a delay between them. Coalesce the burst into one re-assert.
  Timer? _deviceChangeDebounce;
  String _lastDeviceSignature = '';

  void _startDeviceChangeWatch() {
    if (_deviceChangeSub != null) return;
    try {
      _deviceChangeSub = lk.Hardware.instance.onDeviceChange.stream.listen(
        (devices) {
          // Only react when the set of OUTPUTS actually changed; the stream
          // also fires for microphone changes, which must not re-route audio.
          final signature = devices
              .where((d) => d.kind == 'audiooutput')
              .map((d) => d.label)
              .toList()
            ..sort();
          final joined = signature.join('|');
          if (joined == _lastDeviceSignature) return;
          _lastDeviceSignature = joined;

          _deviceChangeDebounce?.cancel();
          _deviceChangeDebounce = Timer(
            const Duration(milliseconds: 250),
            () {
              debugPrint('[LK] audio devices changed -> $joined');
              _reassertSpeakerRoute();
            },
          );
        },
        onError: (Object e) =>
            debugPrint('[LK] device change stream error: $e'),
      );
      debugPrint('[LK] watching audio device changes');
    } catch (e) {
      debugPrint('[LK] could not watch device changes: $e');
    }
  }

  void _stopDeviceChangeWatch() {
    _deviceChangeDebounce?.cancel();
    _deviceChangeDebounce = null;
    _deviceChangeSub?.cancel();
    _deviceChangeSub = null;
    _lastDeviceSignature = '';
  }

  /// Identities reported as speaking on the previous event, so we can send an
  /// explicit zero when they stop. The UI ignores an empty map, so silence has
  /// to be signalled per-identity or the wave would stay stuck on.
  Set<String> _lastSpeakers = <String>{};

  /// livekit_client reports audioLevel as 0.0-1.0; the room UI's thresholds
  /// (speak at 3.0, loud at 28.0) are on the 0-100 scale the previous voice
  /// stack produced. Without this the wave never animates: ordinary speech
  /// reads about 0.3 and never crosses the speaking threshold.
  static const double _audioLevelScale = 100.0;

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
        // This room is audio only. Adaptive stream and dynacast exist to pause
        // and re-size video layers nobody is looking at; with no video they
        // buy nothing and cost a stream of renegotiations, which on a weak
        // connection is heard as the audio breaking up.
        adaptiveStream: false,
        dynacast: false,
        defaultAudioCaptureOptions: lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
        // 32 kbps Opus with DTX: plenty for speech, a third of the default
        // music preset, and silence costs nothing. This is what keeps a room
        // of ten publishers inside a cheap phone's uplink.
        defaultAudioPublishOptions: lk.AudioPublishOptions(
          encoding: lk.AudioEncoding(maxBitrate: 32000),
          dtx: true,
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
        final levels = <String, double>{
          for (final p in e.speakers)
            p.identity: p.audioLevel * _audioLevelScale,
        };
        // Anyone who was speaking and no longer is gets an explicit zero.
        for (final identity in _lastSpeakers) {
          levels.putIfAbsent(identity, () => 0.0);
        }
        _lastSpeakers = e.speakers.map((p) => p.identity).toSet();
        if (levels.isNotEmpty) handler(levels);
      });

    _room = room;
    _events = events;
    _appRoomId = session.appRoomId ?? session.orbitRoomId;

    // The audio session type is decided once, here, from the grant in the
    // token — call audio for someone who may speak, media playback for a
    // listener. It used to be flipped on every mic toggle, and each flip
    // handed routing back to Android (which picks the earpiece) and dropped
    // playback to the much quieter call volume mid-room.
    await _applyAudioSessionFor(publishing: session.canPublish);
    await room.connect(session.livekitUrl, session.token);
    await _reassertSpeakerRoute();
    // From here a headset plugged in mid-call re-routes straight away.
    _startDeviceChangeWatch();

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
    _stopDeviceChangeWatch();
    final room = _room;
    final events = _events;
    _room = null;
    _events = null;
    _appRoomId = null;
    _lastSpeakers = <String>{};
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
      if (enabled && _sessionPublishing != true) {
        // First publish on a connection that was opened as a listener: the
        // seat grant arrived in place, so there was no reconnect to pick the
        // call-mode session. Switch once here, then re-pin the speaker because
        // Android hands routing back to the earpiece on a mode change. After
        // this, mute and unmute leave the session alone (see below).
        await _applyAudioSessionFor(publishing: true);
        await _reassertSpeakerRoute();
      }
      // Just the microphone. The audio session and the output route were both
      // settled at connect and are left alone: muting and unmuting used to
      // trigger a session switch plus four route re-asserts spread over 2.8
      // seconds, and that churn is what made voice cut in and out and jump
      // between the speaker and the earpiece every time someone took the mic.
      await local.setMicrophoneEnabled(enabled);
      return hasLiveMicTrack == enabled;
    } catch (e) {
      debugPrint('[LK] setMicEnabled($enabled): $e');
      return false;
    }
  }

  bool? _sessionPublishing;

  Future<void> _applyAudioSessionFor({required bool publishing}) async {
    if (_sessionPublishing == publishing) return;
    try {
      await lk.AudioManager.instance.setAudioSessionOptions(
        publishing
            ? const lk.AudioSessionOptions.communication()
            : const lk.AudioSessionOptions.mediaPlayback(),
      );
      _sessionPublishing = publishing;
    } catch (e) {
      // Losing the preferred mode must never stop the mic from toggling.
      debugPrint('[LK] audio session switch failed (publishing=$publishing): $e');
    }
  }

  /// Re-apply the user's speaker choice after an audio session change.
  ///
  /// Android routes communication-mode audio through AudioSwitch, whose
  /// device priority is Bluetooth → wired headset → **earpiece** →
  /// speakerphone. The earpiece outranks the speaker, so an unforced
  /// preference loses and the room is heard from the receiver the moment the
  /// mic goes live. Forcing is the only way to win that choice, so force —
  /// but only when no headset is connected, because forcing would otherwise
  /// yank audio out of the user's headphones.
  Future<void> _reassertSpeakerRoute() async {
    try {
      final labels = await _audioOutputLabels();
      final headset = labels.any(_isHeadsetLabel);

      // AudioSwitch picks the first available device from a preferred list,
      // and only the FORCED list puts the speaker ahead of the earpiece:
      //   forced     -> [Speakerphone, Bluetooth, Wired, Earpiece]
      //   preferred  -> [Bluetooth, Wired, Speakerphone, Earpiece]
      //   neither    -> [Bluetooth, Wired, Earpiece, Speakerphone]
      //
      // Speaker ON therefore has to force, unconditionally. Making this
      // conditional on headset detection meant one wrong reading silently
      // disabled the fix and the room went back to the earpiece — which is
      // exactly what kept happening. Speaker OFF uses the unforced list,
      // where a headset still wins and the earpiece is the fallback, so
      // headphone users have a working route via the speaker toggle.
      // Force only when there is no headset. Forcing puts Speakerphone first
      // and would otherwise rip audio out of someone's headphones; unforced
      // still ranks a headset above the speaker and the earpiece below it.
      // The flip below is what makes either choice actually take effect.
      // With a headset connected, do not ask for the loudspeaker at all.
      //
      // Passing `_speakerOn` straight through still reached
      // Native.setAndroidSpeakerphoneOn(true, force: false) — i.e. "speakerphone
      // on, just don't force it". AudioSwitch honours that the moment it
      // re-sorts devices, a couple of seconds after capture starts, which is
      // why audio played through the headset for 2-3 seconds and then jumped
      // back to the speaker. The user's speaker preference is remembered in
      // `_speakerOn` and comes back the instant the headset is unplugged.
      final wantSpeaker = _speakerOn && !headset;
      final force = wantSpeaker;

      // AudioSwitch.setPreferredDeviceList returns immediately when the list
      // it is handed equals the one already held — verified in its bytecode:
      //     areEqual -> ifeq -> return
      // So re-requesting the same routing after unmuting did nothing at all,
      // and whichever device was picked during the session switch (the
      // earpiece) stayed selected. Handing it a DIFFERENT list first makes
      // the real call re-sort the devices and re-select, which is precisely
      // what toggling the output device by hand does.
      await lk.AudioManager.instance.setSpeakerOutputPreferred(!wantSpeaker);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await lk.AudioManager.instance.setSpeakerOutputPreferred(
        wantSpeaker,
        force: force,
      );
      debugPrint(
        '[LK] speaker route: pref=$wantSpeaker (toggle=$_speakerOn) '
        'headset=$headset force=$force devices=$labels',
      );
    } catch (e) {
      debugPrint('[LK] speaker route re-assert failed: $e');
    }
  }

  /// Labels of the audio outputs LiveKit currently reports.
  Future<List<String>> _audioOutputLabels() async {
    try {
      final outputs = await lk.Hardware.instance.audioOutputs();
      return outputs.map((d) => d.label).toList(growable: false);
    } catch (e) {
      debugPrint('[LK] audioOutputs lookup failed: $e');
      return const [];
    }
  }

  static bool _isHeadsetLabel(String raw) {
    final l = raw.toLowerCase();
    return l.contains('bluetooth') ||
        l.contains('headset') ||
        l.contains('headphone') ||
        l.contains('wired') ||
        l.contains('usb');
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
    await _reassertSpeakerRoute();
  }

  @override
  Future<void> reassertRemoteHearing(String reason) async {
    if (!isConnected) return;
    await setRemoteAudioMuted(_remoteMuted);
    await _reassertSpeakerRoute();
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
