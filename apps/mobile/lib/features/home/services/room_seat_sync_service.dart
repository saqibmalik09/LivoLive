import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_live_broadcast.dart';
import 'room_zego_sync_service.dart';

class RoomSeatSyncService {
  RoomSeatSyncService._();

  static const Duration broadcastSkipFetchWindow = Duration(seconds: 5);
  static const Duration vacatedSeatGuard = Duration(seconds: 15);

  static final Map<String, int> _seatReleaseGeneration = {};

  static String _seatReleaseKey(String roomId, String userId) =>
      '$roomId:$userId';

  static int scheduleSeatRelease(String roomId, String userId) {
    final key = _seatReleaseKey(roomId, userId);
    final next = (_seatReleaseGeneration[key] ?? 0) + 1;
    _seatReleaseGeneration[key] = next;
    return next;
  }

  static void invalidateSeatRelease(String roomId, String userId) {
    scheduleSeatRelease(roomId, userId);
  }

  static bool shouldRunSeatRelease(
    String roomId,
    String userId,
    int generation,
  ) {
    return _seatReleaseGeneration[_seatReleaseKey(roomId, userId)] ==
        generation;
  }

  static Future<void> broadcastPrimary({
    required String zegoRoomId,
    RealtimeChannel? backupChannel,
    required Map<String, dynamic> payload,
  }) async {
    await RoomZegoSyncService.broadcastPrimary(
      zegoRoomId: zegoRoomId,
      event: RoomLiveBroadcast.seat,
      payload: payload,
      backupChannel: backupChannel,
    );
    debugPrint(
      '[RoomSeat] broadcast action=${payload['action']} seat=${payload['seat_index']}',
    );
  }

  static void persistAsync(
    Future<void> Function() dbOp, {
    String logTag = 'RoomSeatSync',
    Duration retryAfter = const Duration(seconds: 3),
  }) {
    unawaited(() async {
      try {
        await dbOp();
      } catch (e, st) {
        debugPrint('[$logTag] persist failed: $e');
        debugPrint('$st');
        try {
          await Future<void>.delayed(retryAfter);
          await dbOp();
        } catch (retryError) {
          debugPrint('[$logTag] persist retry failed: $retryError');
        }
      }
    }());
  }

  static bool shouldSkipFetch(DateTime? lastBroadcastAt) {
    if (lastBroadcastAt == null) return false;
    return DateTime.now().difference(lastBroadcastAt) <
        broadcastSkipFetchWindow;
  }

  static void markVacated(
    Map<String, DateTime> recentlyVacated,
    String? userId,
  ) {
    if (userId == null || userId.isEmpty) return;
    recentlyVacated[userId] = DateTime.now();
    final cutoff = DateTime.now().subtract(vacatedSeatGuard);
    recentlyVacated.removeWhere((_, at) => at.isBefore(cutoff));
  }

  static void clearVacated(
    Map<String, DateTime> recentlyVacated,
    String? userId,
  ) {
    if (userId == null || userId.isEmpty) return;
    recentlyVacated.remove(userId);
  }

  static bool wasRecentlyVacated(
    Map<String, DateTime> recentlyVacated,
    String? userId,
  ) {
    if (userId == null || userId.isEmpty) return false;
    final at = recentlyVacated[userId];
    if (at == null) return false;
    return DateTime.now().difference(at) < vacatedSeatGuard;
  }
}
