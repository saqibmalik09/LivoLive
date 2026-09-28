import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class RoomLiveBroadcast {
  RoomLiveBroadcast._();

  static const chat = 'room_chat';
  static const gift = 'room_gift';
  static const seat = 'room_seat';
  static const kick = 'room_kick';
  static const meta = 'room_meta';
  static const micEmoji = 'room_mic_emoji';
  static const entrance = 'room_entrance';
  static const luckyWin = 'room_lucky_win';
  static const presence = 'room_presence';
  static const equip = 'room_equip';

  static const eventChat = chat;
  static const eventGift = gift;
  static const eventSeat = seat;
  static const eventKick = kick;
  static const eventMeta = meta;
  static const eventEntrance = entrance;
  static const eventPresence = presence;
  static const eventEmoji = micEmoji;
  static const eventEquip = equip;

  static const events = {
    chat,
    gift,
    seat,
    kick,
    meta,
    micEmoji,
    entrance,
    luckyWin,
  };

  static String newEventId() => const Uuid().v4();

  static Future<void> send(
    RealtimeChannel channel,
    String event,
    Map<String, dynamic> payload,
  ) async {
    try {
      await channel.sendBroadcastMessage(event: event, payload: payload);
    } catch (e) {
      debugPrint('RoomLiveBroadcast.send($event): $e');
    }
  }

  static void sendBackup(
    RealtimeChannel? channel,
    String event,
    Map<String, dynamic> payload,
  ) {
    if (channel == null) return;
    unawaited(
      send(channel, event, payload).catchError((Object e) {
        debugPrint('[RoomBroadcast] backup failed event=$event: $e');
      }),
    );
  }

  static bool shouldIgnore(
    Set<String> seenIds,
    String? eventId, {
    int maxSize = 200,
  }) {
    if (eventId == null || eventId.isEmpty) return false;
    if (seenIds.contains(eventId)) return true;
    seenIds.add(eventId);
    while (seenIds.length > maxSize) {
      final first = seenIds.first;
      seenIds.remove(first);
    }
    return false;
  }

  static Map<String, dynamic> unwrapPayload(Map<String, dynamic> raw) {
    final inner = raw['payload'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return Map<String, dynamic>.from(raw);
  }

  static Map<String, dynamic> envelope({
    required String roomId,
    required String actorUserId,
    required Map<String, dynamic> fields,
    String? eventId,
  }) {
    return {
      'event_id': eventId ?? newEventId(),
      'room_id': roomId,
      'actor_user_id': actorUserId,
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };
  }
}
