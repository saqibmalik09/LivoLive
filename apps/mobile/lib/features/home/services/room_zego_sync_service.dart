import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:sk_live/core/util/app_constants.dart';

import 'room_live_broadcast.dart';
import 'room_realtime_socket.dart';

class RoomZegoEvent {
  const RoomZegoEvent({required this.event, required this.payload});

  final String event;
  final Map<String, dynamic> payload;
}

class RoomZegoSyncService {
  RoomZegoSyncService._();

  static const envelopePrefix = 'sk_evt:';

  static String encode({
    required String event,
    required Map<String, dynamic> payload,
  }) {
    return '$envelopePrefix${jsonEncode({'event': event, 'payload': payload})}';
  }

  static RoomZegoEvent? decode(String message) {
    if (!message.startsWith(envelopePrefix)) return null;
    try {
      final decoded = jsonDecode(message.substring(envelopePrefix.length));
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        final event = map['event']?.toString();
        final payload = map['payload'];
        if (event != null && event.isNotEmpty && payload is Map) {
          return RoomZegoEvent(
            event: event,
            payload: Map<String, dynamic>.from(payload),
          );
        }
      }
    } catch (e) {
      debugPrint('[RoomSync] decode envelope failed: $e');
    }
    return null;
  }

  static Future<bool> broadcastPrimary({
    required String zegoRoomId,
    required String event,
    required Map<String, dynamic> payload,
    dynamic backupChannel,
    Map<String, dynamic>? zegoPayload,
    bool priority = false,
  }) async {
    if (!AppConstants.useRealtimeGateway) {
      debugPrint('[RoomSync] gateway disabled — refusing publish event=$event');
      return false;
    }
    final roomId =
        payload['room_id']?.toString() ??
        RoomRealtimeSocket.instance.joinedRoomId ??
        '';
    if (roomId.isEmpty) {
      debugPrint('[RoomSync] gateway publish skipped — no roomId event=$event');
      return false;
    }
    final res = await RoomRealtimeSocket.instance.publish(
      roomId: roomId,
      event: event,
      data: payload,
      persistMeta: event == RoomLiveBroadcast.eventMeta,
    );
    final ok = res?['ok'] == true;
    debugPrint('[Gateway] publish event=$event ok=$ok');
    return ok;
  }
}
