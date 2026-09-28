import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/dev/demo_mock_data.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/util/app_constants.dart';

String roomContributionDbPeriod(String period) {
  final normalized = period.toLowerCase();
  if (normalized == 'week' || normalized == 'weekly') {
    return 'weekly';
  }
  return 'daily';
}

int roomContributionTotal(List<GiftRankingModel> list) {
  return list.fold(0, (sum, entry) => sum + entry.score);
}

final roomContributionRankingsProvider =
    FutureProvider.family<List<GiftRankingModel>, (String, String)>((
      ref,
      params,
    ) async {
      final roomId = params.$1;
      final period = params.$2;

      if (kDebugMode && AppConstants.useRoomContributionMockData) {
        return DemoMockData.roomContributionRankings();
      }

      final supabase = Supabase.instance.client;
      final dbPeriod = roomContributionDbPeriod(period);

      try {
        final response = await supabase.rpc(
          'get_room_contribution_rankings',
          params: {'p_room_id': roomId, 'p_ranking_type': dbPeriod},
        );

        final rows = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (rows.isEmpty) {
          if (kDebugMode && AppConstants.useRoomContributionMockData) {
            return DemoMockData.roomContributionRankings();
          }
          return [];
        }

        final userIds = rows
            .map((row) => row['user_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList();

        final usersById = <String, Map<String, dynamic>>{};
        if (userIds.isNotEmpty) {
          final usersResponse = await supabase
              .from('users')
              .select(
                'id, username, avatar_url, user_level, charm_level, wealth_level, vip_level',
              )
              .inFilter('id', userIds);

          for (final row in usersResponse as List) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = map['id']?.toString();
            if (id != null) usersById[id] = map;
          }
        }

        return rows.map((row) {
          final userId = row['user_id']?.toString() ?? '';
          final user = usersById[userId];
          return GiftRankingModel.fromJson({
            'user_id': userId,
            'score': row['score'] ?? 0,
            'rank': row['rank'] ?? 0,
            'users': user ?? {},
          }, 'Gift');
        }).toList();
      } catch (e) {
        debugPrint('[RoomContribution] fetch failed: $e');
        if (kDebugMode && AppConstants.useRoomContributionMockData) {
          return DemoMockData.roomContributionRankings();
        }
        return [];
      }
    });
