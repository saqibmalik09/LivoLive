import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_shared_audio_session.dart';

class RoomSharedAudioSyncController {
  RoomSharedAudioSyncController({
    required this.roomId,
    required String? Function() currentUserId,
    required String Function() currentUsername,
    required bool Function() canManageRoom,
    required void Function(Map<String, dynamic> state) onLocalStateUpdate,
    Future<void> Function(Map<String, dynamic> state)? broadcastState,
  }) : _currentUserId = currentUserId,
       _currentUsername = currentUsername,
       _canManageRoom = canManageRoom,
       _onLocalStateUpdate = onLocalStateUpdate,
       _broadcastState = broadcastState,
       _player = AudioPlayer(
         handleInterruptions: false,
         androidApplyAudioAttributes: false,
       ) {
    _liveControllers.add(this);
    _bindPlayerStreams();
  }

  static const double _catchUpBehindThreshold = 2.5;
  static const double _syncSeekThreshold = 0.4;
  static const double _staleTolerance = 1.5;
  static const Duration _dbDebounceDuration = Duration(seconds: 8);
  static const Duration _viewerPollInterval = Duration(seconds: 20);
  static const double _lateJoinExtrapolateCapSeconds = 20;
  static const Duration _liveVolumeBroadcastMinInterval = Duration(
    milliseconds: 120,
  );
  static const double _liveVolumeBroadcastMinDelta = 0.03;
  static const Duration _playerOpTimeout = Duration(seconds: 8);
  static const double _nearEndToleranceSeconds = 0.45;

  final String roomId;
  String? Function() _currentUserId;
  String Function() _currentUsername;
  bool Function() _canManageRoom;
  void Function(Map<String, dynamic> state) _onLocalStateUpdate;
  Future<void> Function(Map<String, dynamic> state)? _broadcastState;

  String? Function() get currentUserId => _currentUserId;
  String Function() get currentUsername => _currentUsername;
  bool Function() get canManageRoom => _canManageRoom;
  void Function(Map<String, dynamic> state) get onLocalStateUpdate =>
      _onLocalStateUpdate;
  Future<void> Function(Map<String, dynamic> state)? get broadcastState =>
      _broadcastState;

  void reattach({
    required String? Function() currentUserId,
    required String Function() currentUsername,
    required bool Function() canManageRoom,
    required void Function(Map<String, dynamic> state) onLocalStateUpdate,
    Future<void> Function(Map<String, dynamic> state)? broadcastState,
  }) {
    _currentUserId = currentUserId;
    _currentUsername = currentUsername;
    _canManageRoom = canManageRoom;
    _onLocalStateUpdate = onLocalStateUpdate;
    _broadcastState = broadcastState;
  }

  final ValueNotifier<RoomSharedAudioSession?> session = ValueNotifier(null);
  final ValueNotifier<double> playbackPosition = ValueNotifier(0);
  final ValueNotifier<double> playbackDuration = ValueNotifier(0);

  final ValueNotifier<double> playbackVolume = ValueNotifier(1.0);

  final ValueNotifier<double> effectiveVolume = ValueNotifier(1.0);

  AudioPlayer _player;
  static final Set<RoomSharedAudioSyncController> _liveControllers =
      <RoomSharedAudioSyncController>{};

  bool _halted = false;
  bool _nearEndArmed = true;
  bool _naturalCompleteFired = false;
  DateTime? _seekGuardUntil;
  double? _seekGuardTarget;

  static Future<void> haltAllPlayback() async {
    await haltPlaybackExceptRoom(null);
  }

  static Future<void> haltPlaybackExceptRoom(String? keepRoomId) async {
    final controllers = _liveControllers.toList(growable: false);
    for (final controller in controllers) {
      if (keepRoomId != null && controller.roomId == keepRoomId) continue;
      await _haltController(controller);
    }
  }

  static Future<void> haltPlaybackForRoom(String roomId) async {
    final controllers = _liveControllers.toList(growable: false);
    for (final controller in controllers) {
      if (controller.roomId != roomId) continue;
      await _haltController(controller);
    }
  }

  static Future<void> _haltController(
    RoomSharedAudioSyncController controller,
  ) async {
    controller._halted = true;
    controller.stopRemotePoll();
    controller._stopHeartbeatTimer();
    try {
      await controller._player.stop();
    } catch (_) {}
    try {
      await controller._player.setVolume(0);
    } catch (_) {}
  }

  Future<void> reassertPlaybackOutput() async {
    if (_halted || session.value?.isActive != true) return;
    await _applyVolume(effectiveVolume.value);
    if (session.value?.isPlaying != true) return;
    Future<void> retry(Duration delay) async {
      await Future<void>.delayed(delay);
      if (_halted || session.value?.isPlaying != true) return;
      await _applyVolume(effectiveVolume.value);
    }

    unawaited(retry(const Duration(milliseconds: 300)));
    unawaited(retry(const Duration(milliseconds: 1200)));
  }

  Future<void> _playerOp(
    Future<void> Function() op, {
    required String label,
    Duration? timeout,
  }) async {
    try {
      await op().timeout(timeout ?? _playerOpTimeout);
    } on TimeoutException {
      debugPrint('[RoomSharedAudio] $label timed out');
      rethrow;
    }
  }

  void _bindPlayerStreams() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _positionSub = _player.positionStream.listen((duration) {
      if (_applying) return;
      final seconds = duration.inMilliseconds / 1000.0;
      final guardUntil = _seekGuardUntil;
      final guardTarget = _seekGuardTarget;
      if (guardUntil != null && DateTime.now().isBefore(guardUntil)) {
        if (guardTarget != null && (seconds - guardTarget).abs() > 1.5) {
          return;
        }
      } else if (guardUntil != null) {
        _seekGuardUntil = null;
        _seekGuardTarget = null;
      }

      final knownDur = playbackDuration.value > 1
          ? playbackDuration.value
          : (session.value?.duration ?? 0);
      if (knownDur <= 1.0) {
        if (seconds >= 0) playbackPosition.value = seconds;
        return;
      }
      if (seconds > knownDur + 1.0) return;
      playbackPosition.value = seconds.clamp(0.0, knownDur);
      _maybeFireNearEndComplete(playbackPosition.value);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (duration == null || duration.inMilliseconds <= 1000) return;
      final seconds = duration.inMilliseconds / 1000.0;
      playbackDuration.value = seconds;
      final current = session.value;
      if (current != null &&
          (current.duration <= 1 || (current.duration - seconds).abs() > 1)) {
        session.value = current.copyWith(duration: seconds);
      }
    });
    _completeSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _fireNaturalComplete('player_complete');
      }
    });
  }

  Future<Duration?> _loadUrl(String url) async {
    final dur = await _player
        .setAudioSource(AudioSource.uri(Uri.parse(url)), preload: true)
        .timeout(const Duration(seconds: 12));
    _loadedUrl = url;
    if (dur != null && dur.inMilliseconds > 1000) {
      playbackDuration.value = dur.inMilliseconds / 1000.0;
    }
    return dur;
  }

  void _requestSeek(double seconds, {required bool wantPlaying}) {
    final max = playbackDuration.value > 1
        ? playbackDuration.value
        : (session.value?.duration ?? 0);
    final clamped = max > 1 ? seconds.clamp(0.0, max) : seconds.clamp(0.0, 1e9);
    playbackPosition.value = clamped;
    _lastSyncedRemoteTimestamp = clamped;
    _seekGuardTarget = clamped;
    _seekGuardUntil = DateTime.now().add(const Duration(milliseconds: 1800));
    _resetNaturalCompleteGuards();

    unawaited(() async {
      try {
        await _playerOp(
          () => _player.seek(Duration(milliseconds: (clamped * 1000).round())),
          label: 'seek',
          timeout: const Duration(seconds: 4),
        );
        if (wantPlaying) {
          await _playerOp(() => _player.play(), label: 'seek_play');
        }
      } catch (e) {
        debugPrint('[RoomSharedAudio] seek failed: $e');
      }
    }());
  }

  Future<void> _pollDuration() async {
    for (var i = 0; i < 8; i++) {
      if (_halted) return;
      final dur = _player.duration;
      if (dur != null && dur.inMilliseconds > 1000) {
        playbackDuration.value = dur.inMilliseconds / 1000.0;
        final current = session.value;
        if (current != null && current.duration <= 1) {
          session.value = current.copyWith(duration: playbackDuration.value);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  void _resetNaturalCompleteGuards() {
    _nearEndArmed = true;
    _naturalCompleteFired = false;
  }

  void _fireNaturalComplete(String reason) {
    if (_suppressNaturalComplete || _halted) return;
    if (_naturalCompleteFired) return;
    if (isQueueAdvancing?.call() == true) return;

    if (!isUploader) return;
    _naturalCompleteFired = true;
    debugPrint('[RoomSharedAudio] natural complete ($reason)');
    final handler = onNaturalComplete;
    if (handler != null) {
      handler();
    } else {
      unawaited(stopAudio(reason: 'natural_complete'));
    }
  }

  void _maybeFireNearEndComplete(double position) {
    if (_suppressNaturalComplete || _halted || _naturalCompleteFired) return;
    if (!isUploader) return;
    final current = session.value;
    if (current == null || !current.isActive || !current.isPlaying) return;
    final dur = playbackDuration.value > 0
        ? playbackDuration.value
        : current.duration;
    if (dur < 2) return;
    if (position < dur - _nearEndToleranceSeconds) {
      _nearEndArmed = true;
      return;
    }
    if (!_nearEndArmed) return;
    _nearEndArmed = false;
    _fireNaturalComplete('near_end');
  }

  Timer? _heartbeatTimer;
  Timer? _viewerPollTimer;
  Timer? _dbDebounceTimer;
  Timer? _liveVolumeBroadcastTimer;
  String? _lastLocalUpdatedAt;
  String? _lastAppliedUpdatedAt;
  String? _lastAppliedControlUpdatedAt;
  double _lastSyncedRemoteTimestamp = 0;
  String? _loadedUrl;
  bool _applying = false;
  bool _volumeDragActive = false;
  bool _volumeWriteInFlight = false;
  double? _pendingLiveVolume;
  double? _lastBroadcastVolume;
  DateTime? _lastLiveVolumeBroadcastAt;
  Map<String, dynamic>? _pendingState;
  Map<String, dynamic>? _pendingDbState;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<ProcessingState>? _completeSub;

  VoidCallback? onNaturalComplete;
  bool Function()? isQueueAdvancing;
  bool _suppressNaturalComplete = false;

  bool get isPlayerVisible => session.value?.isActive == true;

  bool get isUploader {
    final me = currentUserId();
    final starter = session.value?.startedBy;
    return me != null &&
        starter != null &&
        me.isNotEmpty &&
        starter.isNotEmpty &&
        me == starter;
  }

  bool get isRoomManager => canManageRoom();

  bool get canControl => isUploader || isRoomManager;

  bool get canAdd {
    if (currentUserId() == null) return false;
    final current = session.value;
    return current == null || !current.isActive;
  }

  bool get isController => isUploader;

  Future<T> runWithoutNaturalComplete<T>(Future<T> Function() fn) async {
    _suppressNaturalComplete = true;
    try {
      return await fn();
    } finally {
      _suppressNaturalComplete = false;
    }
  }

  Future<void> syncFromRoomState(Map<String, dynamic>? state) async {
    await _applyState(_withLateJoinExtrapolation(state));
  }

  Future<void> applyOnlyUpdate(Map<String, dynamic>? state) async {
    final parsed = _normalizeState(state);
    if (parsed == null) return;

    if (_shouldIgnoreRemoteUpdate(parsed)) return;

    onLocalStateUpdate(parsed);
    if (!_isOwnWriteEcho(parsed)) {
      await _applyState(parsed);
    } else {
      _refreshSessionFromState(parsed);
    }
  }

  void startRemoteSync() {
    _viewerPollTimer?.cancel();
    unawaited(_pollRemoteState());
    _viewerPollTimer = Timer.periodic(_viewerPollInterval, (_) {
      unawaited(_pollRemoteState());
    });
  }

  void stopRemotePoll() {
    _viewerPollTimer?.cancel();
    _viewerPollTimer = null;
  }

  void _refreshSessionFromState(Map<String, dynamic>? raw) {
    final next = RoomSharedAudioSession.fromRoomState(raw);
    if (next != null) {
      session.value = next;
      if (!_volumeDragActive &&
          (effectiveVolume.value - next.volume).abs() >= 0.015) {
        playbackVolume.value = next.volume;
        effectiveVolume.value = next.volume;
      }

      if (!next.isPlaying) {
        playbackPosition.value = next.timestamp;
      }
      if (next.duration > 1) playbackDuration.value = next.duration;
    }
  }

  Map<String, dynamic>? _normalizeState(Map<String, dynamic>? state) {
    if (state == null) return null;
    return Map<String, dynamic>.from(state);
  }

  Map<String, dynamic>? _withLateJoinExtrapolation(
    Map<String, dynamic>? state,
  ) {
    final map = _normalizeState(state);
    if (map == null) return null;
    if (map['status']?.toString() != 'playing') return map;
    if (map['is_active'] != true) return map;

    final updatedAt = DateTime.tryParse(map['updated_at']?.toString() ?? '');
    if (updatedAt == null) return map;

    final base = (map['timestamp'] as num?)?.toDouble() ?? 0;
    final ageSec =
        DateTime.now().toUtc().difference(updatedAt.toUtc()).inMilliseconds /
        1000.0;
    if (ageSec <= 0) return map;

    map['timestamp'] = base + ageSec.clamp(0.0, _lateJoinExtrapolateCapSeconds);
    return map;
  }

  Map<String, dynamic> _enrichTimestamp(Map<String, dynamic> state) {
    final enriched = Map<String, dynamic>.from(state);
    final ts = (enriched['timestamp'] as num?)?.toDouble() ?? 0;
    enriched['timestamp_ms'] = (ts * 1000).round();
    return enriched;
  }

  bool _isHeartbeat(Map<String, dynamic> state) {
    return state['sync_kind']?.toString() == 'heartbeat';
  }

  bool _isNewerUpdatedAt(String? remoteAt) {
    if (remoteAt == null) return true;
    if (_lastAppliedControlUpdatedAt == null) return true;
    return remoteAt.compareTo(_lastAppliedControlUpdatedAt!) >= 0;
  }

  bool _shouldIgnoreRemoteUpdate(Map<String, dynamic> state) {
    if (isController) return false;

    final syncKind = state['sync_kind']?.toString() ?? 'control';
    if (syncKind == 'control' ||
        syncKind == 'seek' ||
        syncKind == 'volume' ||
        syncKind == 'track_swap') {
      return false;
    }

    final updatedAt = state['updated_at']?.toString();
    final next = RoomSharedAudioSession.fromRoomState(state);
    final current = session.value;

    if (updatedAt != null &&
        _lastAppliedControlUpdatedAt != null &&
        updatedAt.compareTo(_lastAppliedControlUpdatedAt!) < 0) {
      return true;
    }

    if (next == null || current == null) {
      return _isHeartbeat(state);
    }

    if (current.audioUrl != next.audioUrl) return false;
    if (current.status != next.status) return false;

    if (_isHeartbeat(state)) {
      if (next.isPlaying &&
          current.isPlaying &&
          next.timestamp < _lastSyncedRemoteTimestamp - _staleTolerance) {
        return true;
      }
      return true;
    }

    if (updatedAt != null &&
        updatedAt == _lastAppliedUpdatedAt &&
        (next.timestamp - _lastSyncedRemoteTimestamp).abs() < 0.25) {
      return true;
    }

    return false;
  }

  bool _isOwnWriteEcho(Map<String, dynamic>? state) {
    final me = currentUserId();
    final starter = state?['started_by']?.toString();
    final remoteAt = state?['updated_at']?.toString();
    if (me == null ||
        starter == null ||
        remoteAt == null ||
        _lastLocalUpdatedAt == null) {
      return false;
    }
    return me == starter && remoteAt == _lastLocalUpdatedAt;
  }

  Map<String, dynamic> _withSyncKind(
    Map<String, dynamic> state,
    String syncKind,
  ) {
    return _enrichTimestamp(
      Map<String, dynamic>.from(state)..['sync_kind'] = syncKind,
    );
  }

  Future<void> playAudio({
    required String audioUrl,
    required String title,
    double duration = 0,
  }) async {
    final me = currentUserId();

    if (me == null || !canManageRoom()) return;
    if (!canAdd) return;

    final newState = _withSyncKind({
      'is_active': true,
      'audio_url': audioUrl,
      'title': title,
      'status': 'playing',
      'timestamp': 0,
      'duration': duration,
      'volume': playbackVolume.value.clamp(0.0, 1.0),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'started_by': me,
      'started_by_name': currentUsername(),
    }, 'control');

    await _persistState(newState, updateSession: true, immediateDb: true);
    await _applyState(newState);
    _startHeartbeatTimer();
  }

  Future<void> swapActiveTrack({
    required String audioUrl,
    required String title,
    double duration = 0,
  }) async {
    final me = currentUserId();
    if (me == null || !isUploader || session.value?.isActive != true) {
      return playAudio(audioUrl: audioUrl, title: title, duration: duration);
    }

    final newState = _withSyncKind({
      'is_active': true,
      'audio_url': audioUrl,
      'title': title,
      'status': 'playing',
      'timestamp': 0,
      'duration': duration,
      'volume': playbackVolume.value.clamp(0.0, 1.0),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'started_by': me,
      'started_by_name': currentUsername(),
    }, 'track_swap');

    _lastLocalUpdatedAt = newState['updated_at'] as String?;
    await _applyState(newState);
    await _persistState(
      newState,
      updateSession: false,
      broadcast: true,
      immediateDb: true,
    );
    _startHeartbeatTimer();
  }

  Future<void> togglePlayPause() async {
    if (!canControl || session.value == null) return;

    final current = session.value!;
    final pos = await _currentSeconds();
    final willPlay = !current.isPlaying;

    if (willPlay) {
      try {
        await _playerOp(() => _player.play(), label: 'play');
      } catch (_) {}
      await _applyVolume(playbackVolume.value);
      unawaited(_pollDuration());
      _startHeartbeatTimer();
    } else {
      try {
        await _playerOp(() => _player.pause(), label: 'pause');
      } catch (_) {}
      _stopHeartbeatTimer();
      _dbDebounceTimer?.cancel();
      _pendingDbState = null;
    }

    final newState = _withSyncKind(
      current.toRoomState()
        ..['status'] = willPlay ? 'playing' : 'paused'
        ..['timestamp'] = pos
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String(),
      'control',
    );

    await _persistState(newState, updateSession: true, immediateDb: true);
  }

  Future<void> seekTo(double seconds) async {
    if (!canControl || session.value == null) return;

    final current = session.value!;
    final max = playbackDuration.value > 0
        ? playbackDuration.value
        : (current.duration > 0 ? current.duration : seconds + 1);
    final clamped = seconds.clamp(0.0, max);

    _requestSeek(clamped, wantPlaying: current.isPlaying);

    final newState = _withSyncKind(
      current.toRoomState()
        ..['status'] = current.isPlaying ? 'playing' : 'paused'
        ..['timestamp'] = clamped
        ..['duration'] = max
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String(),
      'seek',
    );

    await _persistState(
      newState,
      updateSession: true,
      immediateDb: false,
      debouncedDb: true,
    );
  }

  void beginVolumeDrag() {
    _volumeDragActive = true;
  }

  void endVolumeDrag() {
    _volumeDragActive = false;
  }

  Future<void> previewVolume(double volume) async {
    if (!canControl || session.value == null) return;
    final clamped = volume.clamp(0.0, 1.0);
    unawaited(_applyVolume(clamped));
    _scheduleLiveVolumeBroadcast(clamped);
  }

  void _scheduleLiveVolumeBroadcast(double volume) {
    _pendingLiveVolume = volume;
    final now = DateTime.now();
    final lastAt = _lastLiveVolumeBroadcastAt;
    final elapsed = lastAt == null
        ? _liveVolumeBroadcastMinInterval
        : now.difference(lastAt);
    if (elapsed >= _liveVolumeBroadcastMinInterval) {
      _liveVolumeBroadcastTimer?.cancel();
      _liveVolumeBroadcastTimer = null;
      _emitLiveVolumeBroadcast(force: false);
      return;
    }
    _liveVolumeBroadcastTimer ??= Timer(
      _liveVolumeBroadcastMinInterval - elapsed,
      () {
        _liveVolumeBroadcastTimer = null;
        _emitLiveVolumeBroadcast(force: false);
      },
    );
  }

  void _emitLiveVolumeBroadcast({required bool force}) {
    if (!canControl || session.value == null) return;
    final pending = _pendingLiveVolume;
    if (pending == null) return;
    final last = _lastBroadcastVolume;
    if (!force &&
        last != null &&
        (pending - last).abs() < _liveVolumeBroadcastMinDelta) {
      return;
    }

    _pendingLiveVolume = null;
    _lastBroadcastVolume = pending;
    _lastLiveVolumeBroadcastAt = DateTime.now();

    final current = session.value!;
    final newState = _withSyncKind(
      current.toRoomState()
        ..['volume'] = pending
        ..['timestamp'] = playbackPosition.value
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String(),
      'volume',
    );
    final enriched = _enrichTimestamp(newState);
    _lastLocalUpdatedAt = enriched['updated_at'] as String?;
    onLocalStateUpdate(enriched);

    final send = broadcastState;
    if (send != null) {
      unawaited(() async {
        try {
          await send(enriched);
        } catch (e) {
          debugPrint('[RoomSharedAudio] live volume broadcast failed: $e');
        }
      }());
    }
    _scheduleDbPersist(enriched);

    if (_pendingLiveVolume != null) {
      _liveVolumeBroadcastTimer?.cancel();
      _liveVolumeBroadcastTimer = Timer(_liveVolumeBroadcastMinInterval, () {
        _liveVolumeBroadcastTimer = null;
        _emitLiveVolumeBroadcast(force: false);
      });
    }
  }

  Future<void> setVolume(double volume) async {
    if (!canControl || session.value == null) return;

    final clamped = volume.clamp(0.0, 1.0);
    _liveVolumeBroadcastTimer?.cancel();
    _liveVolumeBroadcastTimer = null;
    _pendingLiveVolume = clamped;
    _volumeDragActive = false;
    await _applyVolume(clamped);
    final current = session.value;
    if (current != null) {
      session.value = current.copyWith(volume: clamped);
      effectiveVolume.value = clamped;
    }
    _emitLiveVolumeBroadcast(force: true);
  }

  Future<void> _applyVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    final changed = (playbackVolume.value - clamped).abs() >= 0.01;
    playbackVolume.value = clamped;
    if (!_volumeDragActive) {
      effectiveVolume.value = clamped;
    }
    if (!changed && !_volumeDragActive) return;
    if (_volumeDragActive && _volumeWriteInFlight) return;
    _volumeWriteInFlight = true;
    try {
      await _playerOp(
        () => _player.setVolume(clamped),
        label: 'setVolume',
        timeout: const Duration(seconds: 2),
      );
    } catch (_) {
    } finally {
      _volumeWriteInFlight = false;
    }
  }

  Future<void> stopAudio({String reason = 'manual', bool force = false}) async {
    if (!force && !canControl) return;
    final stopped = _withSyncKind(_stoppedState(), 'control');
    await runWithoutNaturalComplete(() async {
      await _persistState(stopped, updateSession: true, immediateDb: true);
      await _applyState(stopped);
    });
    _stopHeartbeatTimer();
  }

  static Future<void> stopIfCurrentUserIsUploader(String roomId) async {
    final controllers = _liveControllers.toList(growable: false);
    for (final controller in controllers) {
      if (controller.roomId != roomId) continue;
      if (!controller.isUploader) continue;
      if (controller.session.value?.isActive != true) continue;
      try {
        await controller.stopAudio(reason: 'uploader_exit', force: true);
      } catch (e) {
        debugPrint('[RoomSharedAudio] stopIfUploader failed: $e');
      }
    }
  }

  Map<String, dynamic> _stoppedState() => {
    'is_active': false,
    'audio_url': '',
    'title': '',
    'status': 'stopped',
    'timestamp': 0,
    'duration': 0,
    'volume': 1.0,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'started_by': null,
    'started_by_name': '',
  };

  Future<void> _flushDb(Map<String, dynamic> state) async {
    _pendingDbState = null;
    try {
      await Supabase.instance.client.rpc(
        'update_room_shared_audio_state',
        params: {'p_room_id': roomId, 'p_shared_audio_state': state},
      );
    } catch (e) {
      debugPrint('[RoomSharedAudio] persist failed: $e');
      rethrow;
    }
  }

  void _scheduleDbPersist(Map<String, dynamic> state) {
    _pendingDbState = Map<String, dynamic>.from(state);
    _dbDebounceTimer?.cancel();
    _dbDebounceTimer = Timer(_dbDebounceDuration, () {
      final pending = _pendingDbState;
      if (pending != null) {
        unawaited(_flushDb(pending));
      }
    });
  }

  Future<void> _persistState(
    Map<String, dynamic> newState, {
    bool updateSession = false,
    bool broadcast = true,
    bool immediateDb = false,
    bool debouncedDb = false,
  }) async {
    final enriched = _enrichTimestamp(newState);
    _lastLocalUpdatedAt = enriched['updated_at'] as String?;
    onLocalStateUpdate(enriched);
    if (updateSession) {
      _refreshSessionFromState(enriched);
    }

    if (broadcast) {
      final send = broadcastState;
      if (send != null) {
        try {
          await send(enriched);
        } catch (e) {
          debugPrint('[RoomSharedAudio] broadcast failed: $e');
        }
      }
    }

    if (immediateDb) {
      _dbDebounceTimer?.cancel();
      _pendingDbState = null;
      await _flushDb(enriched);
    } else if (debouncedDb) {
      _scheduleDbPersist(enriched);
    }
  }

  Future<void> _pollRemoteState() async {
    if (isUploader) return;
    try {
      final res = await Supabase.instance.client
          .from('rooms')
          .select('shared_audio_state')
          .eq('id', roomId)
          .maybeSingle();
      final raw = res?['shared_audio_state'];
      if (raw is Map) {
        await applyOnlyUpdate(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('[RoomSharedAudio] poll failed: $e');
    }
  }

  void _seekAndMark(double seconds) {
    _requestSeek(seconds, wantPlaying: session.value?.isPlaying == true);
  }

  Future<void> _maybeSyncPosition({
    required double remoteTs,
    required bool urlChanged,
    required bool isHeartbeat,
    required bool isPlaying,
    required bool isSeek,
    required bool isControl,
  }) async {
    if (urlChanged) {
      _lastSyncedRemoteTimestamp = remoteTs;
      return;
    }

    if (isHeartbeat) return;

    final local = await _currentSeconds();

    if (isSeek || isControl) {
      if ((local - remoteTs).abs() > _syncSeekThreshold) {
        _seekAndMark(remoteTs);
      } else {
        _lastSyncedRemoteTimestamp = remoteTs;
      }
      return;
    }

    if (!isPlaying) {
      if ((local - remoteTs).abs() > 0.35) {
        _seekAndMark(remoteTs);
      } else {
        _lastSyncedRemoteTimestamp = remoteTs;
      }
      return;
    }

    if (local < remoteTs - _catchUpBehindThreshold) {
      _seekAndMark(remoteTs);
    }
  }

  void _markRemoteApplied(Map<String, dynamic>? stateMap, bool isControl) {
    final updatedAt = stateMap?['updated_at']?.toString();
    if (updatedAt != null) {
      _lastAppliedUpdatedAt = updatedAt;
      if (isControl && _isNewerUpdatedAt(updatedAt)) {
        _lastAppliedControlUpdatedAt = updatedAt;
      }
    }
  }

  Future<void> _applyState(Map<String, dynamic>? raw) async {
    if (_halted) return;
    if (_applying) {
      _pendingState = raw == null ? null : Map<String, dynamic>.from(raw);
      return;
    }
    _applying = true;
    try {
      final stateMap = raw == null ? null : Map<String, dynamic>.from(raw);
      final next = RoomSharedAudioSession.fromRoomState(stateMap);
      final syncKind = stateMap?['sync_kind']?.toString() ?? 'control';
      final isHeartbeat = syncKind == 'heartbeat';
      final isSeek = syncKind == 'seek';
      final isControl = syncKind == 'control' || isSeek;

      if (next == null) {
        _stopHeartbeatTimer();
        try {
          await _playerOp(() => _player.stop(), label: 'stop_inactive');
        } catch (_) {}
        _loadedUrl = null;
        _resetNaturalCompleteGuards();
        _markRemoteApplied(stateMap, isControl);
        _lastSyncedRemoteTimestamp = 0;
        _lastAppliedControlUpdatedAt = null;
        session.value = null;
        playbackPosition.value = 0;
        playbackDuration.value = 0;
        playbackVolume.value = 1.0;
        effectiveVolume.value = 1.0;
        return;
      }

      final urlChanged = _loadedUrl != next.audioUrl;
      final isVolume = syncKind == 'volume';
      final isTrackSwap = syncKind == 'track_swap';

      _markRemoteApplied(stateMap, isControl || isTrackSwap);

      if (isVolume) {
        if (!_volumeDragActive) {
          final current = session.value;
          if (current != null) {
            session.value = current.copyWith(volume: next.volume);
          } else {
            session.value = next;
          }
          await _applyVolume(next.volume);
        }
        return;
      }

      final previousVolume = session.value?.volume ?? effectiveVolume.value;
      session.value = next;
      final volumeChanged = (previousVolume - next.volume).abs() >= 0.015;
      if (!_volumeDragActive && (volumeChanged || urlChanged || isTrackSwap)) {
        await _applyVolume(next.volume);
      }
      if (next.duration > 1) playbackDuration.value = next.duration;

      if (urlChanged || isTrackSwap) {
        _resetNaturalCompleteGuards();
        try {
          await runWithoutNaturalComplete(() async {
            try {
              await _playerOp(() => _player.stop(), label: 'reload_stop');
            } catch (_) {}
            await _playerOp(
              () async {
                await _loadUrl(next.audioUrl);
              },
              label: 'setUrl',
              timeout: const Duration(seconds: 15),
            );
            playbackPosition.value = 0;
            await _applyVolume(next.volume);
          });
        } catch (e) {
          debugPrint('[RoomSharedAudio] reload failed: $e');
          _loadedUrl = null;
          rethrow;
        }
      }

      if (_halted) return;

      if (next.isPlaying) {
        try {
          await _playerOp(() => _player.play(), label: 'apply_play');
        } catch (_) {}
        unawaited(_pollDuration());
        if (volumeChanged || urlChanged || isTrackSwap) {
          await _applyVolume(next.volume);
        }
        if (isUploader) {
          _startHeartbeatTimer();
          if (urlChanged || isTrackSwap) {
            unawaited(reassertPlaybackOutput());
          }
        } else if (urlChanged || isTrackSwap) {
          Future<void> retry(Duration delay) async {
            await Future<void>.delayed(delay);
            if (_halted || session.value?.audioUrl != next.audioUrl) return;
            if (session.value?.isPlaying != true) return;
            try {
              await _player.play();
            } catch (_) {}
            await _applyVolume(next.volume);
          }

          unawaited(retry(const Duration(milliseconds: 400)));
          unawaited(retry(const Duration(milliseconds: 1200)));
        }
      } else {
        try {
          await _playerOp(() => _player.pause(), label: 'apply_pause');
        } catch (_) {}
        playbackPosition.value = next.timestamp;
        if (isUploader) _stopHeartbeatTimer();
      }

      if (!isUploader) {
        await _maybeSyncPosition(
          remoteTs: next.timestamp,
          urlChanged: urlChanged || isTrackSwap,
          isHeartbeat: isHeartbeat,
          isPlaying: next.isPlaying,
          isSeek: isSeek,
          isControl: isControl || isTrackSwap,
        );
      } else if (isSeek && next.timestamp > 0.5) {
        _seekAndMark(next.timestamp);
      }
    } catch (e) {
      debugPrint('[RoomSharedAudio] apply failed: $e');
    } finally {
      _applying = false;
      final pending = _pendingState;
      _pendingState = null;
      if (pending != null) {
        unawaited(_applyState(pending));
      }
    }
  }

  Future<double> _currentSeconds() async {
    try {
      return _player.position.inMilliseconds / 1000.0;
    } catch (_) {
      return playbackPosition.value;
    }
  }

  void _startHeartbeatTimer() {
    _stopHeartbeatTimer();
    if (!isUploader) return;

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (session.value == null || !session.value!.isActive) return;
      if (!session.value!.isPlaying) return;

      final pos = await _currentSeconds();
      final current = session.value!;
      final heartbeat = _withSyncKind(
        current.toRoomState()
          ..['status'] = 'playing'
          ..['timestamp'] = pos
          ..['duration'] = playbackDuration.value > 0
              ? playbackDuration.value
              : current.duration
          ..['updated_at'] = DateTime.now().toUtc().toIso8601String(),
        'heartbeat',
      );

      try {
        await _persistState(heartbeat, broadcast: false, immediateDb: true);
      } catch (_) {}
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> dispose() async {
    _halted = true;
    _liveControllers.remove(this);
    _stopHeartbeatTimer();
    stopRemotePoll();
    _dbDebounceTimer?.cancel();
    _liveVolumeBroadcastTimer?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completeSub?.cancel();
    await _player.dispose();
    session.dispose();
    playbackPosition.dispose();
    playbackDuration.dispose();
    playbackVolume.dispose();
    effectiveVolume.dispose();
  }
}
