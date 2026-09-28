import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_youtube_backend_factory.dart';
import 'room_youtube_player_backend.dart';
import 'room_youtube_session.dart';

class RoomYoutubeSyncController {
  RoomYoutubeSyncController({
    required this.roomId,
    required bool Function() canManageRoom,
    required void Function(Map<String, dynamic> youtubeState)
    onLocalStateUpdate,
    Future<void> Function(Map<String, dynamic> state)? broadcastState,
  }) : _canManageRoom = canManageRoom,
       _onLocalStateUpdate = onLocalStateUpdate,
       _broadcastState = broadcastState;

  static const double _catchUpBehindThreshold = 2.5;
  static const double _seekJumpThreshold = 0.5;
  static const double _syncSeekThreshold = 0.4;
  static const double _staleTolerance = 1.5;
  static const Duration _dbDebounceDuration = Duration(seconds: 8);
  static const Duration _viewerPollInterval = Duration(seconds: 20);
  static const double _lateJoinExtrapolateCapSeconds = 20;

  final String roomId;
  bool Function() _canManageRoom;
  void Function(Map<String, dynamic> youtubeState) _onLocalStateUpdate;
  Future<void> Function(Map<String, dynamic> state)? _broadcastState;

  bool Function() get canManageRoom => _canManageRoom;
  void Function(Map<String, dynamic> youtubeState) get onLocalStateUpdate =>
      _onLocalStateUpdate;
  Future<void> Function(Map<String, dynamic> state)? get broadcastState =>
      _broadcastState;

  void reattach({
    required bool Function() canManageRoom,
    required void Function(Map<String, dynamic> youtubeState)
    onLocalStateUpdate,
    Future<void> Function(Map<String, dynamic> state)? broadcastState,
  }) {
    _canManageRoom = canManageRoom;
    _onLocalStateUpdate = onLocalStateUpdate;
    _broadcastState = broadcastState;
  }

  final ValueNotifier<RoomYoutubeSession?> session = ValueNotifier(null);

  RoomYoutubePlayerBackend _backend = createRoomYoutubePlayerBackend();
  Timer? _heartbeatTimer;
  Timer? _positionWatchTimer;
  Timer? _viewerPollTimer;
  Timer? _dbDebounceTimer;

  String? _lastLocalUpdatedAt;
  String? _lastAppliedUpdatedAt;
  String? _lastAppliedControlUpdatedAt;
  String? _loadedVideoId;
  double _lastSyncedRemoteTimestamp = 0;
  Map<String, dynamic>? _pendingDbState;

  double _lastObservedTime = 0;
  DateTime _lastObservedAt = DateTime.now();
  bool? _lastObservedPlaying;
  DateTime? _seekPublishCooldownUntil;

  bool _applying = false;
  Map<String, dynamic>? _pendingState;

  RoomYoutubePlayerBackend get backend => _backend;

  bool get isPlayerVisible => session.value?.isActive == true;

  Future<void> snapshotPlaybackPosition() async {
    final current = session.value;
    if (current == null || !current.isActive) return;
    try {
      final position = await _backend.currentTimeSeconds();
      if (position <= 0) return;
      session.value = current.copyWith(startAtSeconds: position);
      _lastObservedTime = position;
      _lastObservedAt = DateTime.now();
      debugPrint(
        '[RoomYoutube] snapshot position=${position.toStringAsFixed(1)}s',
      );
    } catch (e) {
      debugPrint('[RoomYoutube] snapshot failed: $e');
    }
  }

  Future<void> syncFromRoomState(Map<String, dynamic>? youtubeState) async {
    await _applyYoutubeState(_withLateJoinExtrapolation(youtubeState));
  }

  Future<void> applyYoutubeOnlyUpdate(
    Map<String, dynamic>? youtubeState,
  ) async {
    final parsed = _normalizeState(youtubeState);
    if (parsed == null) return;
    if (_shouldIgnoreRemoteUpdate(parsed)) return;

    onLocalStateUpdate(parsed);
    if (!_isOwnWriteEcho(parsed)) {
      await _applyYoutubeState(parsed);
    }
  }

  void startRemoteSync() {
    _viewerPollTimer?.cancel();
    unawaited(_pollRemoteState());
    _viewerPollTimer = Timer.periodic(_viewerPollInterval, (_) {
      unawaited(_pollRemoteState());
    });
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

  Map<String, dynamic> _withSyncKind(
    Map<String, dynamic> state,
    String syncKind,
  ) {
    return _enrichTimestamp(
      Map<String, dynamic>.from(state)..['sync_kind'] = syncKind,
    );
  }

  bool _isOwnWriteEcho(Map<String, dynamic>? youtubeState) {
    if (!canManageRoom()) return false;
    final remoteAt = youtubeState?['updated_at']?.toString();
    if (remoteAt == null || _lastLocalUpdatedAt == null) return false;
    return remoteAt == _lastLocalUpdatedAt;
  }

  bool _shouldIgnoreRemoteUpdate(Map<String, dynamic> state) {
    if (canManageRoom()) return false;

    final syncKind = state['sync_kind']?.toString() ?? 'control';
    if (syncKind == 'control') return false;
    if (syncKind == 'seek') {
      final updatedAt = state['updated_at']?.toString();
      if (updatedAt != null &&
          _lastAppliedControlUpdatedAt != null &&
          updatedAt.compareTo(_lastAppliedControlUpdatedAt!) < 0) {
        return true;
      }
      return false;
    }

    final updatedAt = state['updated_at']?.toString();
    final next = _sessionFromState(state);
    final current = session.value;

    if (updatedAt != null &&
        _lastAppliedControlUpdatedAt != null &&
        updatedAt.compareTo(_lastAppliedControlUpdatedAt!) < 0) {
      return true;
    }

    if (next == null || current == null) {
      return _isHeartbeat(state);
    }

    if (current.videoId != next.videoId) return false;
    if (current.status != next.status) return false;

    if (_isHeartbeat(state)) {
      if (next.isPlaying &&
          current.isPlaying &&
          next.startAtSeconds < _lastSyncedRemoteTimestamp - _staleTolerance) {
        return true;
      }
      return true;
    }

    if (updatedAt != null &&
        updatedAt == _lastAppliedUpdatedAt &&
        (next.startAtSeconds - _lastSyncedRemoteTimestamp).abs() < 0.25) {
      return true;
    }

    return false;
  }

  RoomYoutubeSession? _sessionFromState(Map<String, dynamic> state) {
    return RoomYoutubeSession.fromRoomState(state, canControl: canManageRoom());
  }

  Future<void> playVideo(String videoId) async {
    if (!canManageRoom()) return;

    final newState = _withSyncKind({
      'is_active': true,
      'video_id': videoId,
      'status': 'playing',
      'timestamp': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, 'control');

    await _persistYoutubeState(newState, immediateDb: true);
    await _applyYoutubeState(newState);
  }

  Future<void> stopParty() async {
    if (!canManageRoom()) return;

    final newState = _withSyncKind({
      'is_active': false,
      'video_id': '',
      'status': 'paused',
      'timestamp': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, 'control');

    await _persistYoutubeState(newState, immediateDb: true);
    await _applyYoutubeState(newState);
  }

  Future<void> _flushDb(Map<String, dynamic> state) async {
    _pendingDbState = null;
    try {
      await Supabase.instance.client.rpc(
        'update_room_youtube_state',
        params: {'p_room_id': roomId, 'p_youtube_state': state},
      );
    } catch (e) {
      debugPrint('[RoomYoutube] persist failed: $e');
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

  Future<void> _persistYoutubeState(
    Map<String, dynamic> newState, {
    bool broadcast = true,
    bool immediateDb = false,
    bool debouncedDb = false,
  }) async {
    final enriched = _enrichTimestamp(newState);
    _lastLocalUpdatedAt = enriched['updated_at'] as String?;
    onLocalStateUpdate(enriched);

    if (broadcast) {
      final send = broadcastState;
      if (send != null) {
        try {
          await send(enriched);
        } catch (e) {
          debugPrint('[RoomYoutube] broadcast failed: $e');
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
    if (canManageRoom()) return;
    try {
      final res = await Supabase.instance.client
          .from('rooms')
          .select('youtube_state')
          .eq('id', roomId)
          .maybeSingle();
      final raw = res?['youtube_state'];
      if (raw is Map) {
        await applyYoutubeOnlyUpdate(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('[RoomYoutube] poll failed: $e');
    }
  }

  bool _shouldPublishSession(
    RoomYoutubeSession? current,
    RoomYoutubeSession next,
  ) {
    if (current == null) return true;
    if (current.videoId != next.videoId) return true;
    if (current.isActive != next.isActive) return true;
    if (current.status != next.status) return true;
    if (current.canControl != next.canControl) return true;
    return false;
  }

  void _markRemoteApplied(Map<String, dynamic>? stateMap, bool isControl) {
    final updatedAt = stateMap?['updated_at']?.toString();
    if (updatedAt == null) return;
    _lastAppliedUpdatedAt = updatedAt;
    if (isControl) {
      if (_lastAppliedControlUpdatedAt == null ||
          updatedAt.compareTo(_lastAppliedControlUpdatedAt!) >= 0) {
        _lastAppliedControlUpdatedAt = updatedAt;
      }
    }
  }

  Future<void> _maybeSyncPosition({
    required double remoteTs,
    required bool videoChanged,
    required bool isHeartbeat,
    required bool isPlaying,
    required bool isSeek,
    required bool isControl,
  }) async {
    if (videoChanged || _loadedVideoId == null) {
      await _backend.seekTo(remoteTs);
      _lastSyncedRemoteTimestamp = remoteTs;
      return;
    }

    if (isHeartbeat) return;

    final localTime = await _backend.currentTimeSeconds();

    if (isSeek || isControl) {
      if ((localTime - remoteTs).abs() > _syncSeekThreshold) {
        await _backend.seekTo(remoteTs);
      }
      _lastSyncedRemoteTimestamp = remoteTs;
      return;
    }

    if (!isPlaying) {
      if ((localTime - remoteTs).abs() > 0.35) {
        await _backend.seekTo(remoteTs);
      }
      _lastSyncedRemoteTimestamp = remoteTs;
      return;
    }

    if (localTime < remoteTs - _catchUpBehindThreshold) {
      await _backend.seekTo(remoteTs);
      _lastSyncedRemoteTimestamp = remoteTs;
    }
  }

  Future<void> _applyYoutubeState(Map<String, dynamic>? state) async {
    if (_applying) {
      _pendingState = state == null ? null : Map<String, dynamic>.from(state);
      return;
    }
    _applying = true;

    try {
      final stateMap = state == null ? null : Map<String, dynamic>.from(state);
      final canControl = canManageRoom();
      final syncKind = stateMap?['sync_kind']?.toString() ?? 'control';
      final isHeartbeat = syncKind == 'heartbeat';
      final isSeek = syncKind == 'seek';
      final isPlayPauseControl = syncKind == 'control';

      final nextSession = RoomYoutubeSession.fromRoomState(
        stateMap,
        canControl: canControl,
      );

      if (nextSession == null) {
        _stopWatchers();
        _markRemoteApplied(stateMap, isPlayPauseControl);
        _loadedVideoId = null;
        _lastSyncedRemoteTimestamp = 0;
        _lastAppliedControlUpdatedAt = null;
        session.value = null;
        _backend.dispose();
        _backend = createRoomYoutubePlayerBackend();
        return;
      }

      final videoId = nextSession.videoId;
      final remoteTs = nextSession.startAtSeconds;
      final videoChanged = _loadedVideoId != videoId;

      _markRemoteApplied(stateMap, isPlayPauseControl);

      if (videoChanged || session.value == null) {
        session.value = nextSession;
        _loadedVideoId = videoId;
        _lastSyncedRemoteTimestamp = remoteTs;
        if (canControl) {
          _startWatchers(videoId);
        }
        return;
      }

      if (_shouldPublishSession(session.value, nextSession)) {
        session.value = nextSession;
      } else if (isSeek && session.value != null) {
        session.value = session.value!.copyWith(startAtSeconds: remoteTs);
      }

      if (!canControl) {
        if (isPlayPauseControl) {
          final playing = await _backend.isPlaying();
          if (nextSession.isPlaying && !playing) {
            await _backend.play();
          } else if (!nextSession.isPlaying && playing) {
            await _backend.pause();
          }
        }

        if (!isHeartbeat) {
          final shouldBePlaying =
              session.value?.isPlaying ?? nextSession.isPlaying;
          await _maybeSyncPosition(
            remoteTs: remoteTs,
            videoChanged: false,
            isHeartbeat: isHeartbeat,
            isPlaying: shouldBePlaying,
            isSeek: isSeek,
            isControl: isPlayPauseControl,
          );
        }

        if (isSeek && session.value != null && !session.value!.isPlaying) {
          await _backend.pause();
        }
      }
    } catch (e) {
      debugPrint('[RoomYoutube] apply failed: $e');
    } finally {
      _applying = false;
      final pending = _pendingState;
      _pendingState = null;
      if (pending != null) {
        unawaited(_applyYoutubeState(pending));
      }
    }
  }

  Future<void> _publishHostSync({
    required String videoId,
    required double position,
    required bool playing,
    required String syncKind,
  }) async {
    final intendedStatus = syncKind == 'seek'
        ? (session.value?.status ?? 'playing')
        : (playing ? 'playing' : 'paused');

    final state = _withSyncKind({
      'is_active': true,
      'video_id': videoId,
      'status': intendedStatus,
      'timestamp': position,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, syncKind);

    final isSeek = syncKind == 'seek';
    await _persistYoutubeState(
      state,
      immediateDb: !isSeek,
      debouncedDb: isSeek,
    );

    if (isSeek && session.value != null) {
      session.value = session.value!.copyWith(
        startAtSeconds: position,
        status: intendedStatus,
      );
      return;
    }

    final nextSession = _sessionFromState(state);
    if (nextSession != null &&
        _shouldPublishSession(session.value, nextSession)) {
      session.value = nextSession;
    }
  }

  void _startWatchers(String videoId) {
    if (!canManageRoom()) return;
    _stopWatchers();
    _resetPositionWatchBaseline();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (!canManageRoom()) return;
      if (session.value?.isActive != true) return;
      final playing = await _backend.isPlaying();
      if (!playing) return;

      final position = await _backend.currentTimeSeconds();
      final heartbeat = _withSyncKind({
        'is_active': true,
        'video_id': videoId,
        'status': 'playing',
        'timestamp': position,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, 'heartbeat');

      try {
        await _persistYoutubeState(
          heartbeat,
          broadcast: false,
          immediateDb: true,
        );
      } catch (_) {}
    });

    _positionWatchTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (!canManageRoom()) return;
      if (session.value?.isActive != true) return;

      final activeVideoId = session.value!.videoId;
      final playing = await _backend.isPlaying();
      final current = await _backend.currentTimeSeconds();
      final now = DateTime.now();

      if (_lastObservedPlaying != null && _lastObservedPlaying != playing) {
        if (!playing) {
          _seekPublishCooldownUntil = null;
          _dbDebounceTimer?.cancel();
          _pendingDbState = null;
        }

        await _publishHostSync(
          videoId: activeVideoId,
          position: current,
          playing: playing,
          syncKind: 'control',
        );

        _lastObservedPlaying = playing;
        _lastObservedTime = current;
        _lastObservedAt = now;
        return;
      }

      if (_lastObservedPlaying == true) {
        final elapsed = now.difference(_lastObservedAt).inMilliseconds / 1000.0;
        if (elapsed > 0) {
          final actualAdvance = current - _lastObservedTime;
          if ((actualAdvance - elapsed).abs() > _seekJumpThreshold) {
            if (_seekPublishCooldownUntil != null &&
                now.isBefore(_seekPublishCooldownUntil!)) {
              _lastObservedTime = current;
              _lastObservedAt = now;
              return;
            }

            await _publishHostSync(
              videoId: activeVideoId,
              position: current,
              playing: playing,
              syncKind: 'seek',
            );

            _seekPublishCooldownUntil = now.add(
              const Duration(milliseconds: 600),
            );
          }
        }
      }

      _lastObservedTime = current;
      _lastObservedAt = now;
      _lastObservedPlaying = playing;
    });
  }

  void _resetPositionWatchBaseline() {
    _lastObservedAt = DateTime.now();
    _lastObservedTime = session.value?.startAtSeconds ?? 0;
    _lastObservedPlaying = session.value?.isPlaying;
  }

  void _stopWatchers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _positionWatchTimer?.cancel();
    _positionWatchTimer = null;
  }

  void dispose() {
    _stopWatchers();
    _viewerPollTimer?.cancel();
    _dbDebounceTimer?.cancel();
    session.dispose();
    _backend.dispose();
  }
}
