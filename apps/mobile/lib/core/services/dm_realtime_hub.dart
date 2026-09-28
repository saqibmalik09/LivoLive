import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:uuid/uuid.dart';

class DmRealtimeHub {
  DmRealtimeHub._();
  static final DmRealtimeHub instance = DmRealtimeHub._();

  bool _started = false;
  String? activeConversationId;
  DateTime? _inboxCursor;
  Timer? _presencePingTimer;

  final _messageBus = StreamController<Map<String, dynamic>>.broadcast();
  final _inboxBus = StreamController<Map<String, dynamic>>.broadcast();
  final _readBus = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceBus = StreamController<Map<String, dynamic>>.broadcast();

  final Map<String, bool> onlineByUserId = {};

  final List<Map<String, dynamic>> _pendingSends = [];

  Stream<Map<String, dynamic>> get messageEvents => _messageBus.stream;
  Stream<Map<String, dynamic>> get inboxEvents => _inboxBus.stream;
  Stream<Map<String, dynamic>> get readEvents => _readBus.stream;
  Stream<Map<String, dynamic>> get presenceEvents => _presenceBus.stream;

  bool? isOnlineCached(String userId) => onlineByUserId[userId];

  Future<void> ensureStarted() async {
    if (!AppConstants.useDmGateway || !AppConstants.useRealtimeGateway) {
      return;
    }
    if (!_started) {
      _started = true;
      RoomRealtimeSocket.instance.addDmListener(_onDmEvent);
      RoomRealtimeSocket.instance.addDmReconnectListener(_onReconnect);
    }
    try {
      await RoomRealtimeSocket.instance.ensureConnected();
      _startPresencePing();
      unawaited(RoomRealtimeSocket.instance.presencePing());
      debugPrint('[DM_GW] hub started / connected');
    } catch (e) {
      debugPrint('[DM_GW] ensureConnected failed: $e');
    }
  }

  void _startPresencePing() {
    _presencePingTimer?.cancel();
    _presencePingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(RoomRealtimeSocket.instance.presencePing());
    });
  }

  void _onDmEvent(Map<String, dynamic> envelope) {
    final event = envelope['event']?.toString() ?? '';
    final data = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : envelope;
    final conversationId =
        (envelope['conversation_id'] ?? data['conversation_id'])?.toString();

    switch (event) {
      case 'dm_message':
        final message = data['message'];
        if (message is Map) {
          final msg = Map<String, dynamic>.from(message);
          if (conversationId != null) {
            msg['conversation_id'] = conversationId;
          }
          if (!_messageBus.isClosed) {
            _messageBus.add({
              'conversation_id': conversationId ?? msg['conversation_id'],
              'message': msg,
            });
          }
        }
        break;
      case 'dm_read':
        if (!_readBus.isClosed) {
          _readBus.add({'conversation_id': conversationId, ...data});
        }
        break;
      case 'dm_inbox':
        _inboxCursor = DateTime.now().toUtc();
        if (!_inboxBus.isClosed) {
          _inboxBus.add(Map<String, dynamic>.from(data));
        }
        break;
      case 'presence':
        final uid = (data['user_id'] ?? envelope['user_id'])?.toString();
        final online = data['online'] == true;
        if (uid != null && uid.isNotEmpty) {
          onlineByUserId[uid] = online;
          if (!_presenceBus.isClosed) {
            _presenceBus.add({
              'user_id': uid,
              'online': online,
              'updated_at': data['updated_at'],
            });
          }
        }
        break;
      default:
        debugPrint('[DM_GW] unknown event=$event');
    }
  }

  void _onReconnect() {
    debugPrint('[DM_GW] reconnect — sync + flush + presence');
    unawaited(AppTelemetry.logEvent('gateway_reconnect'));
    unawaited(RoomRealtimeSocket.instance.presencePing());
    unawaited(_flushPendingSends());
    final active = activeConversationId;
    if (active != null && active.isNotEmpty) {
      unawaited(syncConversation(active));
    }
    unawaited(syncInbox());
  }

  Future<Map<String, bool>> watchUsers(List<String> userIds) async {
    await ensureStarted();
    final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    final ack = await RoomRealtimeSocket.instance.presenceWatch(ids);
    return _applyOnlineAck(ack);
  }

  Future<Map<String, bool>> queryUsers(List<String> userIds) async {
    await ensureStarted();
    final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    final ack = await RoomRealtimeSocket.instance.presenceQuery(ids);
    return _applyOnlineAck(ack);
  }

  Map<String, bool> _applyOnlineAck(Map<String, dynamic>? ack) {
    final out = <String, bool>{};
    if (ack == null || ack['ok'] != true) return out;
    final raw = ack['online'];
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      final id = key.toString();
      final online = value == true;
      onlineByUserId[id] = online;
      out[id] = online;
    });
    return out;
  }

  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String type,
    String? content,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await ensureStarted();
    final meta = Map<String, dynamic>.from(metadata ?? {});
    final eventId =
        meta['event_id']?.toString() ??
        meta['temp_id']?.toString() ??
        const Uuid().v4();
    meta['event_id'] = eventId;
    if (meta['temp_id'] == null) meta['temp_id'] = eventId;

    final payload = <String, dynamic>{
      'conversationId': conversationId,
      'type': type,
      'content': content,
      'mediaUrl': mediaUrl,
      'metadata': meta,
      'event_id': eventId,
    };

    final t0 = DateTime.now();
    final ack = await RoomRealtimeSocket.instance.dmSend(payload);
    final ms = DateTime.now().difference(t0).inMilliseconds;

    if (ack == null || ack['ok'] != true) {
      final err = ack?['error']?.toString() ?? 'send failed';
      debugPrint('[DM_GW] send fail ms=$ms err=$err');
      if (err == 'offline' || err == 'timeout') {
        _enqueuePending(payload);
      }
      throw err;
    }
    debugPrint('[DM_GW] send ok ms=$ms conv=$conversationId');
    return ack['message'] is Map
        ? Map<String, dynamic>.from(ack['message'] as Map)
        : null;
  }

  void _enqueuePending(Map<String, dynamic> payload) {
    final eid = payload['event_id']?.toString();
    _pendingSends.removeWhere((p) => p['event_id']?.toString() == eid);
    _pendingSends.add(Map<String, dynamic>.from(payload));
    debugPrint('[DM_GW] queued offline send n=${_pendingSends.length}');
  }

  Future<void> _flushPendingSends() async {
    if (_pendingSends.isEmpty) return;
    final queued = List<Map<String, dynamic>>.from(_pendingSends);
    _pendingSends.clear();
    for (final payload in queued) {
      try {
        final ack = await RoomRealtimeSocket.instance.dmSend(payload);
        if (ack == null || ack['ok'] != true) {
          _enqueuePending(payload);
          debugPrint('[DM_GW] flush retry later: ${ack?['error']}');
          break;
        }
        final message = ack['message'];
        if (message is Map) {
          final msg = Map<String, dynamic>.from(message);
          if (!_messageBus.isClosed) {
            _messageBus.add({
              'conversation_id': payload['conversationId'],
              'message': msg,
            });
          }
        }
      } catch (e) {
        _enqueuePending(payload);
        debugPrint('[DM_GW] flush error: $e');
        break;
      }
    }
  }

  Future<void> markRead(String conversationId) async {
    await ensureStarted();
    final ack = await RoomRealtimeSocket.instance.dmRead({
      'conversationId': conversationId,
      'event_id': const Uuid().v4(),
    });
    if (ack == null || ack['ok'] != true) {
      debugPrint('[DM_GW] markRead fail: ${ack?['error']}');
    }
  }

  Future<List<Map<String, dynamic>>> syncConversation(
    String conversationId, {
    String? afterTs,
    String? afterId,
  }) async {
    await ensureStarted();
    final ack = await RoomRealtimeSocket.instance.dmSync({
      'conversationId': conversationId,
      if (afterTs != null) 'after_ts': afterTs,
      if (afterId != null) 'after_id': afterId,
      'limit': AppConstants.dmHydrateLimit,
    });
    if (ack == null || ack['ok'] != true) {
      debugPrint('[DM_GW] sync fail: ${ack?['error']}');
      return const [];
    }
    final raw = ack['messages'];
    if (raw is! List) return const [];
    final messages = raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    debugPrint('[DM_GW] sync gap conv=$conversationId n=${messages.length}');
    for (final msg in messages) {
      if (!_messageBus.isClosed) {
        _messageBus.add({'conversation_id': conversationId, 'message': msg});
      }
    }
    return messages;
  }

  Future<List<Map<String, dynamic>>> syncInbox({String? afterTs}) async {
    await ensureStarted();
    final cursor = afterTs ?? _inboxCursor?.toIso8601String();
    final ack = await RoomRealtimeSocket.instance.dmInboxSync({
      if (cursor != null) 'after_ts': cursor,
      'limit': 100,
    });
    if (ack == null || ack['ok'] != true) {
      debugPrint('[DM_GW] inbox_sync fail: ${ack?['error']}');
      return const [];
    }
    _inboxCursor = DateTime.now().toUtc();
    final raw = ack['conversations'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
}
