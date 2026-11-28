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

  /// Last known headset / Bluetooth / wired presence. Unmute + audio-session
  /// flips often return an empty device list for a beat; treating that as
  /// "no headset" forced the loudspeaker and left hands-free silent.
  bool _headsetPresent = false;
  Timer? _postUnmuteRouteRetry;

  void _startDeviceChangeWatch() {
    if (_deviceChangeSub != null) return;
    try {
      _deviceChangeSub = lk.Hardware.instance.onDeviceChange.stream.listen(
        (devices) {
          // Only react when the set of OUTPUTS actually changed; the stream
          // also fires for microphone changes, which must not re-route audio.
          final outputs = devices
              .where((d) => d.kind == 'audiooutput')
              .toList(growable: false);
          final signature = outputs
              .map((d) => '${d.deviceId}:${d.label}')
              .toList()
            ..sort();
          final joined = signature.join('|');
          if (joined == _lastDeviceSignature) return;
          _lastDeviceSignature = joined;
          _headsetPresent = outputs.any(_isHeadsetDevice);

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
    _postUnmuteRouteRetry?.cancel();
    _postUnmuteRouteRetry = null;
    _deviceChangeSub?.cancel();
    _deviceChangeSub = null;
    _lastDeviceSignature = '';
    _headsetPresent = false;
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

  /// Whether this user may speak: the LiveKit grant, and for an open token also
  /// a seat. An open token (it restricts the sources to the microphone) lets
  /// everyone publish from the moment they join so taking a seat needs no
  /// server round trip, which makes the grant alone useless as an "on a seat"
  /// signal. The rest of the app reads this getter as exactly that signal, so it
  /// keeps meaning "allowed to speak right now".
  @override
  bool get canPublishNow {
    final perms = _room?.localParticipant?.permissions;
    if (perms == null || !perms.canPublish) return false;
    if (perms.canPublishSources.isEmpty) return true;
    return _seatPublishAllowed || DateTime.now().isBefore(_sitIntentUntil);
  }

  bool _seatPublishAllowed = false;
  DateTime _sitIntentUntil = DateTime.fromMillisecondsSinceEpoch(0);
  // Which room the seat flags above belong to. A connect that finishes after
  // the user already tapped or took a seat in that room keeps them; without
  // this the connect reset both and the first unmute was refused.
  String? _seatStateRoomId;

  /// Set by the room screen whenever the user's own seat changes.
  void setSeatPublishAllowed(bool onSeat, {String? roomId}) {
    final wasOnSeat = _seatPublishAllowed;
    _seatPublishAllowed = onSeat;
    if (roomId != null) _seatStateRoomId = roomId;
    // Stepping off a seat: drop call-mode audio so a viewer with earbuds is
    // back on media/A2DP instead of a dead SCO route.
    if (wasOnSeat && !onSeat && _sessionPublishing == true) {
      unawaited(() async {
        await _applyAudioSessionFor(publishing: false);
        await _reassertSpeakerRoute();
      }());
    }
  }

  /// The user tapped a seat and is about to take it. Lets the prepared mic
  /// publish while the seat claim is still in flight; it lapses on its own.
  void markSitIntent({String? roomId}) {
    _sitIntentUntil = DateTime.now().add(const Duration(seconds: 30));
    if (roomId != null) _seatStateRoomId = roomId;
  }

  void clearSitIntent() {
    _sitIntentUntil = DateTime.fromMillisecondsSinceEpoch(0);
  }

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
    // The old room is torn down in the background: waiting for its leave
    // and peer-connection close put a few hundred ms in front of every
    // room switch before the new room was even asked for.
    _detachRoomForReplace();

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
    // The token's own can_publish is seat-derived; it is the starting point for
    // an open token, and the room screen keeps it current from then on.
    final seatStateHere =
        _seatStateRoomId != null && _seatStateRoomId == _appRoomId;
    _seatPublishAllowed =
        session.canPublish || (seatStateHere && _seatPublishAllowed);
    if (!seatStateHere) {
      clearSitIntent();
      _seatStateRoomId = _appRoomId;
    }

    // Always join as a listener (media playback). Call/communication mode is
    // switched on the first mic enable below. Starting every join in call mode
    // — including pure viewers, whose open tokens still carry canPublish —
    // put Android on the Bluetooth SCO / call route with no media stream, so
    // earbuds stayed silent until the user sat and unmuted.
    await _applyAudioSessionFor(publishing: false);
    await room.connect(session.livekitUrl, session.token);
    // Watch first: Bluetooth often enumerates a beat after connect, and the
    // stream is how we catch that without waiting for a manual speaker tap.
    _startDeviceChangeWatch();
    await _reassertSpeakerRoute();
    // Earpods / car kits frequently appear only after SCO/A2DP settles.
    _scheduleHeadsetRouteRetries();
    // The publisher transport's first ICE + DTLS costs ~1.9 s and used to land
    // on the first seat tap, which is the one that felt slow. Pay it just after
    // connect instead, once the connect burst is over.
    Timer(const Duration(seconds: 1), () => unawaited(warmPublisher()));

    // The token's grant is authoritative; only publish if the server allowed it.
    // setMicEnabled switches the session to communication and re-pins the route.
    if (_micIntent && canPublishNow) {
      await setMicEnabled(true);
    }
    debugPrint(
      '[LK] joined room=${session.livekitRoom} publish=$canPublishNow',
    );
  }

  void _detachRoomForReplace() {
    final room = _room;
    final events = _events;
    if (room == null && events == null) return;
    _stopDeviceChangeWatch();
    _room = null;
    _events = null;
    _appRoomId = null;
    _lastSpeakers = <String>{};
    unawaited(discardPrecapturedMic());
    unawaited(() async {
      try {
        await events?.dispose();
        await room?.disconnect();
        await room?.dispose();
      } catch (e) {
        debugPrint('[LK] background logout: $e');
      }
    }());
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
    unawaited(discardPrecapturedMic());
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
        await _enterCallMode();
      } else if (enabled) {
        // Later unmutes leave the session alone, but still re-pin so a wired /
        // Bluetooth headset that was present before mute is not left on speaker.
        await _reassertSpeakerRoute();
      } else if (!enabled && !_seatPublishAllowed) {
        // Left the seat / muted as a viewer again: go back to media playback so
        // earbuds use A2DP instead of a stale SCO call route.
        await _applyAudioSessionFor(publishing: false);
        await _reassertSpeakerRoute();
      }
      // Just the microphone after the route is settled. Avoid flipping the
      // audio session on every mute/unmute — that churn yanked voice between
      // speaker and earpiece.
      await _setMicOnLocal(local, enabled);
      return hasLiveMicTrack == enabled;
    } catch (e) {
      debugPrint('[LK] setMicEnabled($enabled): $e');
      return false;
    }
  }


  // ---------------------------------------------------------- speak warm-up
  //
  // Taking a seat used to run four things strictly one after another: wait for
  // the publish grant (~1.1 s), open the microphone (~1.4 s), publish, then let
  // the publisher transport do ICE + DTLS for the first time (~1.9 s) — the
  // listener is only told about the track once that transport is connected.
  // None of the last three needs the grant to *start*, so they run while the
  // seat claim and the grant are still in flight, and only the publish itself
  // waits for the grant.

  lk.LocalAudioTrack? _precapturedMic;
  Timer? _precaptureExpiry;
  Future<void>? _precaptureFlight;
  Future<void>? _warmPublisherFlight;

  /// A captured mic that is never published must not keep the OS microphone
  /// indicator on, so an unused capture is dropped after this long.
  static const Duration _precaptureTtl = Duration(seconds: 20);

  /// Connects the publisher transport ahead of the first publish. Safe to call
  /// repeatedly; failure only means the first publish connects it as before.
  Future<void> warmPublisher() {
    final room = _room;
    if (room == null || !isConnected) return Future<void>.value();
    return _warmPublisherFlight ??= _warmPublisherNow(room).whenComplete(() {
      _warmPublisherFlight = null;
    });
  }

  Future<void> _warmPublisherNow(lk.Room room) async {
    final sw = Stopwatch()..start();
    try {
      // ignore: invalid_use_of_internal_member
      await room.engine.ensurePublisherConnected();
      debugPrint('[LK] publisher warm ms=${sw.elapsedMilliseconds}');
    } catch (e) {
      debugPrint('[LK] publisher warm failed after ${sw.elapsedMilliseconds}ms: $e');
    }
  }

  /// Opens the microphone now so the later publish does not pay for it.
  /// Needs the OS microphone permission to be granted already.
  Future<void> precaptureMic() {
    final room = _room;
    if (room == null || !isConnected) return Future<void>.value();
    final hasMicPublication =
        room.localParticipant?.getTrackPublicationBySource(lk.TrackSource.microphone) != null;
    if (hasMicPublication || _precapturedMic != null) return Future<void>.value();
    return _precaptureFlight ??= _precaptureNow(room).whenComplete(() {
      _precaptureFlight = null;
    });
  }

  Future<void> _precaptureNow(lk.Room room) async {
    final sw = Stopwatch()..start();
    lk.LocalAudioTrack? track;
    try {
      track = await lk.LocalAudioTrack.create(room.roomOptions.defaultAudioCaptureOptions);
      await track.start();
      if (!identical(room, _room)) {
        await track.stop();
        return;
      }
      _precapturedMic = track;
      _precaptureExpiry?.cancel();
      _precaptureExpiry = Timer(_precaptureTtl, () => unawaited(discardPrecapturedMic()));
    } catch (e) {
      debugPrint('[LK] mic precapture failed after ${sw.elapsedMilliseconds}ms: $e');
      try {
        await track?.stop();
      } catch (stopError) {
        debugPrint('[LK] mic precapture cleanup: $stopError');
      }
    }
  }

  /// Everything the seat claim does not need to wait for: connect the publisher
  /// transport, open the mic, and once the gateway's early grant lands publish
  /// the track *muted*. Taking the seat is then an unmute, one signalling
  /// message, instead of capture + publish + first ICE/DTLS.
  ///
  /// Needs the OS microphone permission already. If the grant never arrives the
  /// capture is dropped by the expiry timer and the normal path still works.
  Future<void> prepareToSpeak() {
    final room = _room;
    if (room == null || !isConnected) return Future<void>.value();
    return _prepareFlight ??= _prepareNow(room).whenComplete(() {
      _prepareFlight = null;
    });
  }

  Future<void>? _prepareFlight;
  String? _preparedSid;

  /// First publish on a connection that was opened as a listener: switch the
  /// audio session to call mode once, then re-pin the speaker because Android
  /// hands routing back to the earpiece on a mode change. After this, mute and
  /// unmute leave the session alone.
  Future<void> _enterCallMode() async {
    if (_sessionPublishing == true) return;
    await _applyAudioSessionFor(publishing: true);
    await _reassertSpeakerRoute();
    // Mode switch briefly drops headset from the enumerated list, and
    // Bluetooth SCO often needs a second pin after it appears.
    _scheduleHeadsetRouteRetries();
  }

  Future<void> _prepareNow(lk.Room room) async {
    // The call-mode switch used to run on "Open Mic", in front of the unmute.
    // Done here it overlaps the dialog. A dismissed dialog switches back in
    // discardPrecapturedMic.
    await _enterCallMode();
    await Future.wait<void>(<Future<void>>[warmPublisher(), precaptureMic()]);
    final granted = await waitForPublishPermission(
      timeout: const Duration(seconds: 4),
    );
    final local = room.localParticipant;
    final track = _precapturedMic;
    if (!granted ||
        local == null ||
        track == null ||
        !identical(room, _room) ||
        local.getTrackPublicationBySource(lk.TrackSource.microphone) != null) {
      return;
    }
    _precapturedMic = null;
    try {
      final publication = await local.publishAudioTrack(track);
      await publication.mute(stopOnMute: false);
      _preparedSid = publication.sid;
      _precaptureExpiry?.cancel();
      _precaptureExpiry = Timer(_precaptureTtl, () => unawaited(discardPrecapturedMic()));
    } catch (e) {
      debugPrint('[LK] prepareToSpeak publish failed: $e');
      try {
        await track.stop();
      } catch (stopError) {
        debugPrint('[LK] prepareToSpeak cleanup: $stopError');
      }
    }
  }

  /// Drops whatever [prepareToSpeak] set up and the user never used: a mic that
  /// was captured but not published, or a track published muted for a seat that
  /// was never taken (claim failed, "Keep Muted", dialog dismissed, timed out).
  Future<void> discardPrecapturedMic() async {
    final roomAtStart = _room;
    _precaptureExpiry?.cancel();
    _precaptureExpiry = null;
    final track = _precapturedMic;
    _precapturedMic = null;
    final sid = _preparedSid;
    _preparedSid = null;
    if (track != null) {
      try {
        await track.stop();
      } catch (e) {
        debugPrint('[LK] discard precaptured mic: $e');
      }
    }
    final local = _room?.localParticipant;
    if (sid != null && local != null) {
      try {
        await local.removePublishedTrack(sid);
      } catch (e) {
        debugPrint('[LK] discard prepared publish: $e');
      }
    }
    // Prepared for a seat that was not taken: back to media playback so
    // earbuds stay on A2DP. Nothing to undo if the mic is actually live.
    final micLive =
        _room?.localParticipant
            ?.getTrackPublicationBySource(lk.TrackSource.microphone) !=
        null;
    if (roomAtStart != null &&
        identical(_room, roomAtStart) &&
        _sessionPublishing == true &&
        !_seatPublishAllowed &&
        !micLive) {
      await _applyAudioSessionFor(publishing: false);
      await _reassertSpeakerRoute();
    }
  }

  /// Removes the microphone publication entirely. Used when leaving a seat: the
  /// gateway revokes publish server-side, so the connection stays up and the
  /// next seat is another prepare + unmute rather than a reconnect.
  Future<void> unpublishMic() async {
    await discardPrecapturedMic();
    final local = _room?.localParticipant;
    final publication = local?.getTrackPublicationBySource(lk.TrackSource.microphone);
    if (local == null || publication == null) return;
    try {
      await local.removePublishedTrack(publication.sid);
    } catch (e) {
      debugPrint('[LK] unpublishMic: $e');
    }
  }

  /// Turns the microphone on or off. A precaptured track is published as-is;
  /// anything else goes through the SDK's own enable/mute path, which also
  /// covers every later mute and unmute because the publication then exists.
  Future<void> _setMicOnLocal(lk.LocalParticipant local, bool enabled) async {
    if (enabled) {
      final preparing = _prepareFlight;
      if (preparing != null) await preparing;
      final inflight = _precaptureFlight;
      if (inflight != null) await inflight;
      final prepared = local.getTrackPublicationBySource(lk.TrackSource.microphone);
      if (prepared != null &&
          prepared.sid == _preparedSid &&
          prepared.track?.isActive == true) {
        // Published muted by prepareToSpeak with the capture still running.
        _preparedSid = null;
        _precaptureExpiry?.cancel();
        _precaptureExpiry = null;
        await prepared.unmute(stopOnMute: false);
        return;
      }
      final precaptured = _precapturedMic;
      final alreadyPublished =
          local.getTrackPublicationBySource(lk.TrackSource.microphone) != null;
      if (precaptured != null && !alreadyPublished) {
        _precapturedMic = null;
        _precaptureExpiry?.cancel();
        _precaptureExpiry = null;
        try {
          await local.publishAudioTrack(precaptured);
        } catch (_) {
          try {
            await precaptured.stop();
          } catch (stopError) {
            debugPrint('[LK] precaptured mic cleanup: $stopError');
          }
          rethrow;
        }
        return;
      }
    }
    await local.setMicrophoneEnabled(enabled);
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
  /// AudioSwitch preferred lists (never forced):
  ///   speaker preferred -> [Bluetooth, Wired, Speakerphone, Earpiece]
  ///   speaker off       -> [Bluetooth, Wired, Earpiece, Speakerphone]
  /// So a connected headset always wins without a manual Output Device tap.
  ///
  /// The old path used `force: true` whenever the Speaker toggle was on and
  /// headset detection missed branded earpods (AirPods, Galaxy Buds, …).
  /// Forced order puts Speakerphone first and keeps audio on the loudspeaker
  /// until the user switches to Earpiece by hand. Never force here — the
  /// Speaker toggle only beats the built-in earpiece when nothing is plugged
  /// in / paired.
  Future<void> _reassertSpeakerRoute() async {
    try {
      final outputs = await _audioOutputDevices();
      final headsetNow = outputs.any(_isHeadsetDevice);
      // Empty enumeration right after unmute must not clear a known headset —
      // that is what forced loudspeaker and left hands-free silent.
      if (outputs.isNotEmpty) {
        _headsetPresent = headsetNow;
      }
      final headset = _headsetPresent || headsetNow;
      final publishing = _sessionPublishing == true;

      if (!publishing) {
        // Viewer / mediaPlayback. Never call selectAudioOutput on Bluetooth
        // here: that switches the phone onto SCO (call audio), and while the
        // session is still mediaPlayback there is nothing on that channel —
        // earbuds go silent. Clear any leftover force-speaker so A2DP / wired
        // media stays on the headset.
        if (headset) {
          await lk.AudioManager.instance.setSpeakerOutputPreferred(
            false,
            force: false,
          );
        } else if (_speakerOn) {
          await lk.AudioManager.instance.setSpeakerOutputPreferred(
            true,
            force: false,
          );
        } else {
          await lk.AudioManager.instance.setSpeakerOutputPreferred(
            false,
            force: false,
          );
        }
        debugPrint(
          '[LK] speaker route (listen): toggle=$_speakerOn headset=$headset '
          'devices=${outputs.map((d) => '${d.deviceId}/${d.label}').toList()}',
        );
        return;
      }

      if (headset) {
        // Clear any stuck forced-speaker preference from a previous build /
        // unmute, then pin the Bluetooth / wired output for call audio (SCO).
        await lk.AudioManager.instance.setSpeakerOutputPreferred(
          false,
          force: false,
        );
        await _selectHeadsetOutput(outputs);
      } else {
        // Prefer speaker for the party room (beats earpiece). Never force —
        // that would beat a headset that appears a moment later.
        // AudioSwitch.setPreferredDeviceList no-ops when the list is unchanged.
        // Flip once so the real preference re-sorts and re-selects.
        await lk.AudioManager.instance.setSpeakerOutputPreferred(
          !_speakerOn,
          force: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await lk.AudioManager.instance.setSpeakerOutputPreferred(
          _speakerOn,
          force: false,
        );
      }
      debugPrint(
        '[LK] speaker route (publish): toggle=$_speakerOn headset=$headset '
        'force=false '
        'devices=${outputs.map((d) => '${d.deviceId}/${d.label}').toList()}',
      );
    } catch (e) {
      debugPrint('[LK] speaker route re-assert failed: $e');
    }
  }

  /// Bluetooth / USB earpods often show up hundreds of ms after join or after
  /// the call-mode switch. Re-run routing a few times so the user does not
  /// have to open Output Device by hand.
  void _scheduleHeadsetRouteRetries() {
    _postUnmuteRouteRetry?.cancel();
    const delays = <int>[400, 1200, 2500];
    var i = 0;
    void arm() {
      if (i >= delays.length) return;
      _postUnmuteRouteRetry = Timer(Duration(milliseconds: delays[i++]), () {
        unawaited(_reassertSpeakerRoute());
        arm();
      });
    }

    arm();
  }

  /// Prefer a connected Bluetooth / wired / USB headset on Android.
  ///
  /// Bluetooth first, to match the order AudioSwitch itself prefers, so the
  /// explicit selection cannot disagree with the preference we just set.
  Future<void> _selectHeadsetOutput(List<lk.MediaDevice> outputs) async {
    try {
      lk.MediaDevice? headset;
      for (final d in outputs) {
        if (!_isHeadsetDevice(d)) continue;
        final bluetooth = _isBluetoothDevice(d);
        if (bluetooth) {
          headset = d;
          break;
        }
        headset ??= d;
      }
      if (headset == null) return;
      await lk.Hardware.instance.selectAudioOutput(headset);
    } catch (e) {
      debugPrint('[LK] select headset output failed: $e');
    }
  }

  Future<List<lk.MediaDevice>> _audioOutputDevices() async {
    try {
      return await lk.Hardware.instance.audioOutputs();
    } catch (e) {
      debugPrint('[LK] audioOutputs lookup failed: $e');
      return const [];
    }
  }

  /// External audio (earpods / headset / car / USB) vs the phone's own
  /// speaker and earpiece.
  ///
  /// Android reports `deviceId` / `groupId` as the AudioSwitch kind
  /// (`bluetooth`, `wired-headset`, `speaker`, `earpiece`) while `label` is
  /// the product name — "AirPods Pro", "Galaxy Buds", "boAt Rockerz". iOS
  /// reports `groupId` as the AVAudioSession port type (`BluetoothHFP`,
  /// `Headphones`, `USBAudio`). Matching only generic words in the label
  /// missed every branded pair, so routing treated them as missing and kept
  /// the loudspeaker. Anything that is not the built-in speaker/earpiece is
  /// treated as an external route.
  static bool _isHeadsetDevice(lk.MediaDevice d) {
    if (_isBuiltinPhoneOutput(d)) return false;
    if (_isHeadsetRouteId(d.deviceId) ||
        _isHeadsetRouteId(d.groupId ?? '') ||
        _isHeadsetLabel(d.label)) {
      return true;
    }
    // Branded earbuds often only expose a product label and a non-builtin id.
    return true;
  }

  static bool _isBuiltinPhoneOutput(lk.MediaDevice d) {
    for (final raw in [d.deviceId, d.groupId ?? '', d.label]) {
      final id = raw.toLowerCase().trim();
      if (id.isEmpty) continue;
      if (id == 'speaker' ||
          id == 'speakerphone' ||
          id == 'earpiece' ||
          id == 'receiver' ||
          id == 'phone' ||
          id == 'built-in speaker' ||
          id == 'built-in receiver') {
        return true;
      }
      if (id.contains('built-in') &&
          (id.contains('speaker') ||
              id.contains('receiver') ||
              id.contains('earpiece'))) {
        return true;
      }
    }
    return false;
  }

  static bool _isBluetoothDevice(lk.MediaDevice d) {
    for (final v in [d.deviceId, d.groupId ?? '', d.label]) {
      final s = v.toLowerCase();
      if (s.contains('bluetooth') ||
          s.contains('a2dp') ||
          s.contains('hfp') ||
          s.contains('sco') ||
          s.contains('airpod') ||
          s.contains('buds')) {
        return true;
      }
    }
    return false;
  }

  static bool _isHeadsetRouteId(String raw) {
    final id = raw.toLowerCase();
    if (id.isEmpty) return false;
    // The built-in routes on both platforms: Android "speaker" / "earpiece",
    // iOS port types "Speaker" / "Receiver".
    if (id == 'speaker' ||
        id == 'speakerphone' ||
        id == 'earpiece' ||
        id == 'receiver') {
      return false;
    }
    return id.contains('bluetooth') ||
        id.contains('headset') ||
        id.contains('headphone') ||
        id.contains('earpod') ||
        id.contains('earphone') ||
        id.contains('wired') ||
        id.contains('usb') ||
        id.contains('a2dp') ||
        id.contains('hfp') ||
        id.contains('sco') ||
        id.contains('caraudio') ||
        id.contains('airplay');
  }

  static bool _isHeadsetLabel(String raw) {
    final l = raw.toLowerCase();
    return l.contains('bluetooth') ||
        l.contains('headset') ||
        l.contains('headphone') ||
        l.contains('earpod') ||
        l.contains('earphone') ||
        l.contains('airpod') ||
        l.contains('buds') ||
        l.contains('beats') ||
        l.contains('wired') ||
        l.contains('usb') ||
        l.contains('a2dp') ||
        l.contains('sco') ||
        l.contains('ble');
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
      await Future<void>.delayed(const Duration(milliseconds: 50));
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
