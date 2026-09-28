import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/gift_provider.dart';

class RankingRoomPromo {
  const RankingRoomPromo({
    required this.rank,
    required this.roomId,
    required this.title,
    this.imageUrl,
    this.score = 0,
  });

  final int rank;
  final String roomId;
  final String title;
  final String? imageUrl;
  final int score;
}

class RankingRoomPromoService {
  RankingRoomPromoService._();

  static const _prefPrefix = 'ranking_room_promo_';

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String _userId() =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  static Future<bool> shouldShowToday() async {
    final userId = _userId();
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefPrefix${userId}_${_todayKey()}') != true;
  }

  static Future<void> markShownToday() async {
    final userId = _userId();
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefPrefix${userId}_${_todayKey()}', true);
  }

  static Future<List<RankingRoomPromo>> loadTopPromos({
    required Future<List<GiftRankingModel>> Function() fetchRoomDayRankings,
  }) async {
    try {
      final list = await fetchRoomDayRankings();
      if (list.isEmpty) return [];

      RankingRoomPromo? pick(int rank) {
        GiftRankingModel? row;
        for (final r in list) {
          if (r.rank == rank) {
            row = r;
            break;
          }
        }
        row ??= list.length >= rank ? list[rank - 1] : null;
        if (row == null) return null;
        final id = row.userId.trim();
        if (id.isEmpty) return null;
        return RankingRoomPromo(
          rank: rank,
          roomId: id,
          title: row.username.trim().isEmpty ? 'Top Room' : row.username.trim(),
          imageUrl: row.avatarUrl,
          score: row.score,
        );
      }

      final out = <RankingRoomPromo>[];
      final first = pick(1);
      final third = pick(3);
      if (first != null) out.add(first);
      if (third != null && third.roomId != first?.roomId) out.add(third);
      return out;
    } catch (e) {
      debugPrint('[RankingRoomPromo] load failed: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchRoomMap(String roomId) async {
    try {
      final row = await Supabase.instance.client
          .from('rooms')
          .select('*, host:host_id(username, avatar_url, short_id)')
          .eq('id', roomId)
          .eq('is_active', true)
          .maybeSingle();
      if (row == null) return null;
      final room = Map<String, dynamic>.from(row);
      final host = room['host'];
      if (host is Map) {
        room['host_name'] = host['username'] ?? room['host_name'];
        room['host_avatar'] = host['avatar_url'] ?? room['host_avatar'];
      }
      return room;
    } catch (e) {
      debugPrint('[RankingRoomPromo] fetchRoomMap failed: $e');
      return null;
    }
  }
}
