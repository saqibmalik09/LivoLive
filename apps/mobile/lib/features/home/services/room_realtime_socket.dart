import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/features/home/services/room_live_broadcast.dart';

typedef RoomGatewayEventHandler =
    void Function(String event, Map<String, dynamic> data);

typedef RoomGatewaySnapshotHandler =
    void Function(Map<String, dynamic> snapshot);

typedef GlobalWinGatewayHandler = void Function(Map<String, dynamic> data);
typedef GlobalBigGiftGatewayHandler = void Function(Map<String, dynamic> data);

typedef DmGatewayEventHandler = void Function(Map<String, dynamic> envelope);

typedef DmGatewayReconnectHandler = void Function();

class RoomRealtimeSocket {
  RoomRealtimeSocket._();

  static final RoomRealtimeSocket instance = RoomRealtimeSocket._();

  io.Socket? _socket;
  String? _joinedRoomId;
  Map<String, dynamic>? _joinedUser;
  String? _pendingRoomId;
  Map<String, dynamic>? _pendingUser;
  bool _rejoining = false;
  // LiveKit session handed to us by a join or sit ack, waiting to be consumed
  // by the voice engine. See takeVoiceSession.
  Map<String, dynamic>? _prefetchedVoice;
  String? _prefetchedVoiceRoomId;
  RoomGatewayEventHandler? onEvent;
  RoomGatewaySnapshotHandler? onSnapshot;
  GlobalWinGatewayHandler? onGlobalWin;
  GlobalBigGiftGatewayHandler? onGlobalBigGift;
  final List<DmGatewayEventHandler> _dmListeners = [];
  final List<DmGatewayReconnectHandler> _dmReconnectListeners = [];

  Completer<void>? _connectWait;
  bool _connecting = false;
  int _authRetryCount = 0;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  bool get isConnected => _socket?.connected == true;
  String? get joinedRoomId => _joinedRoomId;

  bool isJoinedTo(String roomId) => isConnected && _joinedRoomId == roomId;

  void addDmListener(DmGatewayEventHandler handler) {
    if (!_dmListeners.contains(handler)) {
      _dmListeners.add(handler);
    }
  }

  void removeDmListener(DmGatewayEventHandler handler) {
    _dmListeners.remove(handler);
  }

  void addDmReconnectListener(DmGatewayReconnectHandler handler) {
    if (!_dmReconnectListeners.contains(handler)) {
      _dmReconnectListeners.add(handler);
    }
  }

  void removeDmReconnectListener(DmGatewayReconnectHandler handler) {
    _dmReconnectListeners.remove(handler);
  }

  void _dispatchDm(Map<String, dynamic> envelope) {
    for (final handler in List<DmGatewayEventHandler>.from(_dmListeners)) {
      try {
        handler(envelope);
      } catch (e) {
        debugPrint('[DM_GW] listener error: $e');
      }
    }
  }

  void _dispatchDmReconnect() {
    for (final handler in List<DmGatewayReconnectHandler>.from(
      _dmReconnectListeners,
    )) {
      try {
        handler();
      } catch (e) {
        debugPrint('[DM_GW] reconnect listener error: $e');
      }
    }
  }

  Future<void> ensureConnected() async {
    if (!AppConstants.useRealtimeGateway) return;
    if (isConnected) return;

    await AppTelemetry.traceAsync('gateway_connect', () async {
      if (_connecting) {
        final wait = _connectWait;
        if (wait != null) {
          try {
            await wait.future.timeout(const Duration(seconds: 12));
          } catch (_) {}
        }
        if (isConnected) return;
      }

      _connecting = true;
      final wait = Completer<void>();
      _connectWait = wait;
      try {
        await _connectWithAuthRetry();
        await _rejoinCurrentRoom();
        if (!wait.isCompleted) wait.complete();
      } catch (e) {
        if (!wait.isCompleted) wait.completeError(e);
        rethrow;
      } finally {
        _connecting = false;
        if (identical(_connectWait, wait)) _connectWait = null;
      }
    }, slowMs: 6000);
  }

  Future<void> _connectWithAuthRetry() async {
    try {
      await _connect(forceWaitForFreshToken: false);
      _authRetryCount = 0;
    } catch (e) {
      if (_isUnauthorized(e) && _authRetryCount < 2) {
        _authRetryCount++;
        debugPrint(
          '[Gateway] unauthorized — waiting for GoTrue auto-refresh '
          '(try $_authRetryCount)',
        );
        _disposeSocketOnly();
        await _connect(forceWaitForFreshToken: true);
        _authRetryCount = 0;
        return;
      }
      rethrow;
    }
  }

  Future<String> _resolveAccessToken({bool waitForFresh = false}) async {
    final auth = Supabase.instance.client.auth;

    Future<Session?> readSession() async => auth.currentSession;

    bool usable(Session? s) {
      if (s == null) return false;
      final token = s.accessToken;
      if (token.isEmpty) return false;
      final exp = s.expiresAt;
      if (exp == null) return true;
      final secondsLeft = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
      ).difference(DateTime.now()).inSeconds;
      return secondsLeft > 20;
    }

    var session = await readSession();
    if (usable(session) && !waitForFresh) {
      return session!.accessToken;
    }

    final deadline = DateTime.now().add(
      Duration(milliseconds: waitForFresh ? 4000 : 1500),
    );
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      session = await readSession();
      if (usable(session)) return session!.accessToken;
    }

    session = await readSession();
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('No Supabase access token for gateway');
    }
    debugPrint(
      '[Gateway] using access token without manual refresh '
      '(expired=${session?.isExpired})',
    );
    return token;
  }

  Future<void> _connect({required bool forceWaitForFreshToken}) async {
    final token = await _resolveAccessToken(
      waitForFresh: forceWaitForFreshToken,
    );

    final completer = Completer<void>();
    _disposeSocketOnly();

    _socket = io.io(
      AppConstants.realtimeGatewayUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({
            'token': token,
            'mtoken': AppConstants.maintenanceBypassToken,
          })
          .disableReconnection()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        debugPrint('[Gateway] connected');
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _reconnectAttempt = 0;
        if (!completer.isCompleted) completer.complete();
        unawaited(_rejoinCurrentRoom());
        _dispatchDmReconnect();
      })
      ..onDisconnect((_) {
        debugPrint('[Gateway] disconnected');
        _scheduleReconnect();
      })
      ..onConnectError((e) {
        debugPrint('[Gateway] connect error: $e');
        if (!completer.isCompleted) {
          completer.completeError(e ?? 'connect error');
        }
      })
      ..on('room:event', (raw) {
        final envelope = _asMap(raw);
        if (envelope == null) return;
        final event = envelope['event']?.toString() ?? '';
        final data = _asMap(envelope['data']) ?? envelope;
        if (event.isEmpty) return;
        onEvent?.call(event, data);
      })
      ..on('room:snapshot', (raw) {
        final snap = _asMap(raw);
        if (snap != null) onSnapshot?.call(snap);
      })
      ..on('global:win', (raw) {
        final envelope = _asMap(raw);
        if (envelope == null) return;
        final data = _asMap(envelope['data']) ?? envelope;
        onGlobalWin?.call(data);
      })
      ..on('global:big_gift', (raw) {
        final envelope = _asMap(raw);
        if (envelope == null) return;
        final data = _asMap(envelope['data']) ?? envelope;
        onGlobalBigGift?.call(data);
      })
      ..on('lucky:win', (raw) {
        final envelope = _asMap(raw);
        if (envelope == null) return;
        final data = _asMap(envelope['data']) ?? envelope;
        onEvent?.call('lucky_win', data);
      })
      ..on('dm:event', (raw) {
        final envelope = _asMap(raw);
        if (envelope == null) return;
        _dispatchDm(envelope);
      })
      ..connect();

    await completer.future.timeout(const Duration(seconds: 12));
  }

  void _scheduleReconnect() {
    if (_joinedRoomId == null) return;
    if (_reconnectTimer?.isActive == true) return;

    const backoff = [1, 2, 4, 8, 15];
    final delaySeconds =
        backoff[_reconnectAttempt.clamp(0, backoff.length - 1)];
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      if (_joinedRoomId == null || isConnected) return;
      try {
        await ensureConnected();
      } catch (e) {
        debugPrint('[Gateway] reconnect attempt failed: $e');
        _scheduleReconnect();
      }
    });
  }

  Future<void> _rejoinCurrentRoom() async {
    final roomId = _joinedRoomId ?? _pendingRoomId;
    final user = _joinedUser ?? _pendingUser;
    if (roomId == null || user == null || _rejoining) return;
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    _rejoining = true;
    try {
      debugPrint('[Gateway] rejoin room=$roomId after reconnect');
      final res = await _emitAckRaw('room:join', {
        'roomId': roomId,
        'user': user,
        'snapshotRequest': true,
        'event_id': RoomLiveBroadcast.newEventId(),
      });
      if (res?['ok'] == true) {
        _joinedRoomId = roomId;
        _joinedUser = Map<String, dynamic>.from(user);
        _rememberVoiceSession(roomId, res);
      } else {
        final err = res?['error']?.toString() ?? 'rejoin_failed';
        debugPrint('[Gateway] rejoin failed: $err');
        if (err == 'kicked_from_room') {
          _joinedRoomId = null;
          _joinedUser = null;
        }
      }
    } catch (e) {
      debugPrint('[Gateway] rejoin failed: $e');
    } finally {
      _rejoining = false;
    }
  }

  Future<Map<String, dynamic>?> joinRoom({
    required String roomId,
    required Map<String, dynamic> user,
    String? eventId,
    bool snapshotRequest = true,
    String? carSvga,
    String? pattiSvga,
    String? pattiUrl,
  }) async {
    _pendingRoomId = roomId;
    _pendingUser = Map<String, dynamic>.from(user);
    _joinedUser = Map<String, dynamic>.from(user);
    await ensureConnected();

    final previousRoomId = _joinedRoomId;
    if (previousRoomId != null &&
        previousRoomId.isNotEmpty &&
        previousRoomId != roomId) {
      debugPrint(
        '[Gateway] leave previous room=$previousRoomId before join=$roomId',
      );
      final uid = user['id']?.toString();
      if (uid != null && uid.isNotEmpty) {
        try {
          await seatLeave({
            'roomId': previousRoomId,
            'user_id': uid,
            'event_id': RoomLiveBroadcast.newEventId(),
          });
        } catch (e) {
          debugPrint('[Gateway] seatLeave previous before join failed: $e');
        }
      }
      await _emitAckRaw('room:leave', {
        'roomId': previousRoomId,
        'user': user,
        'event_id': RoomLiveBroadcast.newEventId(),
      });
      if (_joinedRoomId == previousRoomId) _joinedRoomId = null;
    }

    final res = await _emitAckRaw('room:join', {
      'roomId': roomId,
      'user': user,
      'event_id': eventId ?? RoomLiveBroadcast.newEventId(),
      'snapshotRequest': snapshotRequest,
      if (carSvga != null) 'carSvga': carSvga,
      if (pattiSvga != null) 'pattiSvga': pattiSvga,
      if (pattiUrl != null) 'pattiUrl': pattiUrl,
    });
    if (res?['ok'] == true) {
      _joinedRoomId = roomId;
      _joinedUser = Map<String, dynamic>.from(user);
      _rememberVoiceSession(roomId, res);
    }
    return res;
  }

  Future<void> leaveRoom({
    required String roomId,
    required Map<String, dynamic> user,
  }) async {
    if (_pendingRoomId == roomId) {
      _pendingRoomId = null;
      _pendingUser = null;
    }
    if (_joinedRoomId == roomId) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempt = 0;
    }
    if (isConnected) {
      try {
        await _emitAckRaw('room:leave', {
          'roomId': roomId,
          'user': user,
          'event_id': RoomLiveBroadcast.newEventId(),
        });
      } catch (e) {
        debugPrint('[Gateway] room:leave emit failed: $e');
      }
    }
    if (_joinedRoomId == roomId) {
      _joinedRoomId = null;
      _joinedUser = null;
    }
    if (_prefetchedVoiceRoomId == roomId) _clearVoiceSession();
  }

  Future<Map<String, dynamic>?> heartbeat({
    required String roomId,
    required Map<String, dynamic> user,
  }) async {
    final live = _joinedRoomId;
    if (live != roomId) {
      debugPrint(
        '[Gateway] skip stale heartbeat beat=$roomId live=${live ?? 'none'}',
      );
      return {'ok': false, 'error': 'stale_room'};
    }
    try {
      await ensureConnected();
    } catch (e) {
      debugPrint('[Gateway] heartbeat ensureConnected failed: $e');
      return {'ok': false, 'error': 'offline'};
    }
    return _emitAckRaw('presence:heartbeat', {'roomId': roomId, 'user': user});
  }

  Future<Map<String, dynamic>?> requestSnapshot(String roomId) {
    return _emitAck('room:snapshot', {'roomId': roomId});
  }

  /// A LiveKit session the gateway sent along with a join or sit ack, so the
  /// voice engine can connect without asking for a token first.
  ///
  /// One-shot: taking it clears it, so a stale token is never reused after the
  /// user's seat state has changed.
  Map<String, dynamic>? takeVoiceSession(String roomId) {
    if (_prefetchedVoiceRoomId != roomId) return null;
    final session = _prefetchedVoice;
    _prefetchedVoice = null;
    _prefetchedVoiceRoomId = null;
    return session;
  }

  void _rememberVoiceSession(dynamic roomId, Map<String, dynamic>? ack) {
    final id = roomId?.toString();
    if (id == null || id.isEmpty) return;
    final voice = ack?['voice'];
    if (voice is! Map) return;
    _prefetchedVoice = Map<String, dynamic>.from(voice);
    _prefetchedVoiceRoomId = id;
  }

  void _clearVoiceSession() {
    _prefetchedVoice = null;
    _prefetchedVoiceRoomId = null;
  }

  /// Takes a seat. Prefers `seat:sit`, which writes the seat and returns a
  /// LiveKit publish token in the same ack — the old sequence was claim, then
  /// voice:token, then poll for publish permission, then reconnect, which is
  /// where the long wait before anyone could hear you came from.
  ///
  /// Falls back to `seat:claim` if the gateway does not answer `seat:sit`, so a
  /// client that reaches a server older than this still seats the user.
  Future<Map<String, dynamic>?> seatClaim(Map<String, dynamic> payload) async {
    final res = await _emitAck('seat:sit', payload);
    if (res?['error']?.toString() == 'timeout') {
      debugPrint('[Gateway] seat:sit unanswered, falling back to seat:claim');
      return _emitAck('seat:claim', payload);
    }
    _rememberVoiceSession(payload['roomId'], res);
    return res;
  }

  Future<Map<String, dynamic>?> seatLeave(Map<String, dynamic> payload) {
    return _emitAck('seat:leave', payload);
  }

  Future<Map<String, dynamic>?> seatMute(Map<String, dynamic> payload) {
    return _emitAck('seat:mute', payload);
  }

  Future<Map<String, dynamic>?> seatLock(Map<String, dynamic> payload) {
    return _emitAck('seat:lock', payload);
  }

  Future<Map<String, dynamic>?> chatSend(Map<String, dynamic> payload) {
    return _emitAck('chat:send', payload);
  }

  Future<Map<String, dynamic>?> dmSend(Map<String, dynamic> payload) {
    return _emitAck('dm:send', payload);
  }

  Future<Map<String, dynamic>?> dmRead(Map<String, dynamic> payload) {
    return _emitAck('dm:read', payload);
  }

  Future<Map<String, dynamic>?> dmSync(Map<String, dynamic> payload) {
    return _emitAck('dm:sync', payload);
  }

  Future<Map<String, dynamic>?> dmInboxSync(Map<String, dynamic> payload) {
    return _emitAck('dm:inbox_sync', payload);
  }

  Future<Map<String, dynamic>?> voiceToken(Map<String, dynamic> payload) {
    return _emitAck('voice:token', payload);
  }

  Future<Map<String, dynamic>?> presencePing() {
    return _emitAck('presence:ping', {});
  }

  Future<Map<String, dynamic>?> presenceQuery(List<String> userIds) {
    return _emitAck('presence:query', {'userIds': userIds});
  }

  Future<Map<String, dynamic>?> presenceWatch(List<String> userIds) {
    return _emitAck('presence:watch', {'userIds': userIds});
  }

  Future<Map<String, dynamic>?> presenceUnwatch(List<String> userIds) {
    return _emitAck('presence:unwatch', {'userIds': userIds});
  }

  Future<Map<String, dynamic>?> giftNotify(Map<String, dynamic> payload) {
    return _emitAck('gift:notify', payload);
  }

  Future<Map<String, dynamic>?> giftSend(Map<String, dynamic> payload) {
    return _emitAck('gift:send', payload);
  }

  Future<Map<String, dynamic>?> winNotify(Map<String, dynamic> payload) {
    return _emitAck('win:notify', payload);
  }

  Future<Map<String, dynamic>?> reportActivity({
    required String roomId,
    required bool isOnMic,
  }) {
    return _emitAck('activity:report', {'roomId': roomId, 'isOnMic': isOnMic});
  }

  Future<Map<String, dynamic>?> publish({
    required String roomId,
    required String event,
    required Map<String, dynamic> data,
    bool persistMeta = false,
  }) {
    return _emitAck('room:publish', {
      'roomId': roomId,
      'event': event,
      'data': data,
      'persistMeta': persistMeta,
    });
  }

  Future<Map<String, dynamic>?> _emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    try {
      await ensureConnected();
    } catch (e) {
      debugPrint('[Gateway] emit ensureConnected failed event=$event: $e');
      return {
        'ok': false,
        'error': _isUnauthorized(e) ? 'unauthorized' : 'offline',
      };
    }
    return _emitAckRaw(event, payload);
  }

  Future<Map<String, dynamic>?> _emitAckRaw(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      debugPrint('[Gateway] emit skipped (offline) event=$event');
      return {'ok': false, 'error': 'offline'};
    }

    final completer = Completer<Map<String, dynamic>?>();
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic response) {
        if (completer.isCompleted) return;
        completer.complete(_asMap(response));
      },
    );
    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Gateway] ack timeout event=$event: $e');
      return {'ok': false, 'error': 'timeout'};
    }
  }

  static bool _isUnauthorized(Object? e) {
    final s = e?.toString().toLowerCase() ?? '';
    return s.contains('unauthorized');
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void _disposeSocketOnly() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    onEvent = null;
    onSnapshot = null;
    onGlobalWin = null;
    onGlobalBigGift = null;
    _pendingRoomId = null;
    _pendingUser = null;
    _joinedRoomId = null;
    _joinedUser = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _disposeSocketOnly();
  }
}
