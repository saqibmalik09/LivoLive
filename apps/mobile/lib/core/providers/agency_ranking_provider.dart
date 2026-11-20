import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';

class AgencyRankingModel {
  const AgencyRankingModel({
    required this.agencyId,
    required this.name,
    this.avatarUrl,
    required this.score,
    required this.rank,
    this.rankFrame,
    this.rankBadge,
    this.levelBadgeUrl,
  });

  final String agencyId;
  final String name;
  final String? avatarUrl;
  final int score;
  final int rank;
  final String? rankFrame;
  final String? rankBadge;
  final String? levelBadgeUrl;
}

String _dbPeriod(String period) {
  final p = period.toLowerCase();
  if (p == 'day') return 'daily';
  if (p == 'week') return 'weekly';
  if (p == 'month') return 'monthly';
  return p;
}

Future<Map<int, Map<String, String?>>> _fetchAgencyAssets(
  String dbPeriod,
) async {
  final response = await Supabase.instance.client
      .from('ranking_assets')
      .select('rank_position, frame_url, badge_url')
      .eq('ranking_type', dbPeriod)
      .eq('category', 'Agency');

  final map = <int, Map<String, String?>>{};
  for (final row in response as List) {
    final pos = (row['rank_position'] as num?)?.toInt();
    if (pos == null) continue;
    map[pos] = {
      'frame_url': row['frame_url'] as String?,
      'badge_url': row['badge_url'] as String?,
    };
  }
  return map;
}

final agencyOwnerExpProvider = FutureProvider<int>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;

  var totalExp = 0;
  try {
    // Summed server-side — the unbounded select over earning_logs timed out for
    // owners with a large history and took this provider down with it.
    final total = await Supabase.instance.client.rpc(
      'agency_total_exp',
      params: <String, dynamic>{'p_owner_id': userId},
    );
    totalExp = (total as num?)?.toInt() ?? 0;

    final agency = await ref.watch(myAgencyProvider.future);
    if (agency != null) {
      final ranking = await Supabase.instance.client
          .from('agency_rankings')
          .select('score')
          .eq('agency_id', agency['id'])
          .eq('ranking_type', 'weekly')
          .maybeSingle();
      final rankScore = (ranking?['score'] as num?)?.toInt() ?? 0;
      if (rankScore > totalExp) totalExp = rankScore;
    }
  } catch (e) {
    debugPrint('[AgencyRanking] owner exp fetch failed: $e');
  }
  return totalExp;
});

final myAgencyProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    return await Supabase.instance.client
        .from('agencies')
        .select('id, name')
        .eq('owner_id', userId)
        .maybeSingle();
  } catch (e) {
    debugPrint('[AgencyRanking] my agency fetch failed: $e');
    return null;
  }
});

final agencyRankingsProvider =
    FutureProvider.family<List<AgencyRankingModel>, String>((
      ref,
      period,
    ) async {
      final supabase = Supabase.instance.client;
      final dbPeriod = _dbPeriod(period);

      try {
        final response = await supabase
            .from('agency_rankings')
            .select(
              '*, agencies:agency_id(name, owner_id, users!owner_id(username, avatar_url))',
            )
            .eq('ranking_type', dbPeriod)
            .order('rank', ascending: true)
            .limit(30);

        final assets = await _fetchAgencyAssets(dbPeriod);
        final levelConfigs = await ref.watch(agencyLevelConfigsProvider.future);

        final rows = (response as List)
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .toList();

        final weeklyScoreByAgency = <String, int>{};
        if (dbPeriod == 'weekly') {
          for (final json in rows) {
            final id = json['agency_id']?.toString() ?? '';
            if (id.isEmpty) continue;
            weeklyScoreByAgency[id] = (json['score'] as num?)?.toInt() ?? 0;
          }
        } else {
          final ids = rows
              .map((j) => j['agency_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          if (ids.isNotEmpty) {
            final weekly = await supabase
                .from('agency_rankings')
                .select('agency_id, score')
                .eq('ranking_type', 'weekly')
                .inFilter('agency_id', ids);
            for (final row in weekly as List) {
              final id = row['agency_id']?.toString() ?? '';
              if (id.isEmpty) continue;
              weeklyScoreByAgency[id] = (row['score'] as num?)?.toInt() ?? 0;
            }
          }
        }

        return rows.map((json) {
          final agency = json['agencies'] as Map<String, dynamic>? ?? {};
          final owner = agency['users'] as Map<String, dynamic>? ?? {};
          final rank = (json['rank'] as num?)?.toInt() ?? 0;
          final asset = assets[rank] ?? {};
          final agencyId = json['agency_id']?.toString() ?? '';
          final score = (json['score'] as num?)?.toInt() ?? 0;
          final levelExp = weeklyScoreByAgency[agencyId] ?? score;
          final level = agencyLevelFromExp(levelConfigs, levelExp);
          final levelConfig = agencyConfigForLevel(levelConfigs, level);

          return AgencyRankingModel(
            agencyId: agencyId,
            name:
                agency['name'] as String? ??
                owner['username'] as String? ??
                'Agency',
            avatarUrl: owner['avatar_url'] as String?,
            score: score,
            rank: rank,
            rankFrame: asset['frame_url'],
            rankBadge: asset['badge_url'],
            levelBadgeUrl: levelConfig == null
                ? null
                : agencyBadgeUrl(levelConfig),
          );
        }).toList();
      } catch (e) {
        debugPrint('[AgencyRanking] fetch failed: $e');
        return [];
      }
    });
