import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, int>> fetchRoomsRecentGiftTotals(
  Iterable<String> roomIds, {
  int minutes = 30,
}) async {
  final ids = roomIds.where((e) => e.isNotEmpty).toList();
  if (ids.isEmpty) return {};

  try {
    final response = await Supabase.instance.client.rpc(
      'get_rooms_recent_gift_totals',
      params: {'p_room_ids': ids, 'p_minutes': minutes},
    );

    final map = <String, int>{};
    for (final row in (response as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['room_id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = (m['total'] as num?)?.toInt() ?? 0;
    }
    return map;
  } catch (_) {
    return {};
  }
}

String roomsDailyGiftTotalsKey(Iterable<Map<String, dynamic>> rooms) {
  final ids =
      rooms
          .map((r) => r['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return ids.join(',');
}

final roomsDailyGiftTotalsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, joinedRoomIds) async {
      final ids = joinedRoomIds
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      return fetchRoomsRecentGiftTotals(ids);
    });
