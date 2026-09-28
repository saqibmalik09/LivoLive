import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/providers/gift_provider.dart';

Future<void> refreshGameRankings() async {
  try {
    await Supabase.instance.client.rpc('refresh_game_rankings');
  } catch (e) {
    debugPrint('[GameRanking] refresh failed: $e');
  }
}

final gameRankingsProvider =
    FutureProvider.family<List<GiftRankingModel>, String>((ref, period) async {
      final supabase = Supabase.instance.client;

      String dbPeriod = period.toLowerCase();
      if (dbPeriod == 'day') {
        dbPeriod = 'daily';
      } else if (dbPeriod == 'week') {
        dbPeriod = 'weekly';
      } else if (dbPeriod == 'month') {
        dbPeriod = 'monthly';
      }

      try {
        final response = await supabase
            .from('game_rankings')
            .select(
              '*, users:user_id(username, avatar_url, user_level, wealth_level)',
            )
            .eq('ranking_type', dbPeriod)
            .order('rank', ascending: true)
            .limit(30);

        return (response as List).map((json) {
          final map = Map<String, dynamic>.from(json);
          return GiftRankingModel.fromJson(map, 'Gift');
        }).toList();
      } catch (e) {
        debugPrint('[GameRanking] fetch failed: $e');
        return [];
      }
    });
