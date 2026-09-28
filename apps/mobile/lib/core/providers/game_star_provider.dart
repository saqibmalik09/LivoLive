import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameStarUserRank {
  const GameStarUserRank({
    required this.userId,
    required this.score,
    required this.rank,
    this.username,
    this.avatarUrl,
    this.shortId,
  });

  final String userId;
  final int score;
  final int rank;
  final String? username;
  final String? avatarUrl;
  final String? shortId;

  String get displayName =>
      username?.trim().isNotEmpty == true ? username!.trim() : 'User';

  String get displayId =>
      shortId?.trim().isNotEmpty == true ? shortId!.trim() : '--';

  factory GameStarUserRank.fromJson(Map<String, dynamic> json) {
    return GameStarUserRank(
      userId: (json['user_id'] ?? '').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      shortId: (json['short_id'] ?? json['shortId'])?.toString(),
    );
  }
}

class GameStarGameItem {
  const GameStarGameItem({
    required this.id,
    required this.name,
    required this.iconUrl,
  });

  final String id;
  final String name;
  final String iconUrl;
}

class GameStarHistoryWeek {
  GameStarHistoryWeek({
    required this.periodKey,
    required this.periodStart,
    required this.periodEnd,
    required this.top3,
  });

  final String periodKey;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final List<GameStarUserRank> top3;
}

class GameStarRewardItem {
  const GameStarRewardItem({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;
}

class GameStarRewardSlots {
  const GameStarRewardSlots({
    required this.rank1Label,
    required this.rank1Items,
    required this.rank2Label,
    required this.rank2Items,
    required this.rank3Label,
    required this.rank3Items,
    required this.rank4to10Label,
    required this.rank4to10Items,
  });

  final String rank1Label;
  final List<GameStarRewardItem> rank1Items;
  final String rank2Label;
  final List<GameStarRewardItem> rank2Items;
  final String rank3Label;
  final List<GameStarRewardItem> rank3Items;
  final String rank4to10Label;
  final List<GameStarRewardItem> rank4to10Items;

  static GameStarRewardItem _item(dynamic raw, [String fallback = '']) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return GameStarRewardItem(
        label: (m['label'] as String?)?.trim().isNotEmpty == true
            ? m['label'] as String
            : fallback,
        imageUrl: (m['image_url'] as String?)?.trim() ?? '',
      );
    }
    return GameStarRewardItem(label: fallback, imageUrl: '');
  }

  static (String, List<GameStarRewardItem>) _tier(
    dynamic raw,
    String fallbackLabel,
  ) {
    if (raw is! Map) {
      return (fallbackLabel, <GameStarRewardItem>[]);
    }
    final m = Map<String, dynamic>.from(raw);
    final label = (m['label'] as String?)?.trim().isNotEmpty == true
        ? m['label'] as String
        : fallbackLabel;
    final items = <GameStarRewardItem>[];
    final itemsRaw = m['items'];
    if (itemsRaw is List && itemsRaw.isNotEmpty) {
      for (final it in itemsRaw) {
        items.add(_item(it));
      }
    } else if ((m['image_url'] as String?)?.trim().isNotEmpty == true ||
        (m['label'] as String?)?.trim().isNotEmpty == true) {
      items.add(_item(m, fallbackLabel));
    }
    return (
      label,
      items.where((i) => i.imageUrl.isNotEmpty || i.label.isNotEmpty).toList(),
    );
  }

  factory GameStarRewardSlots.fromConfig(Map<String, dynamic> config) {
    final raw = config['reward_slots'];
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final t1 = _tier(map['rank_1'], 'Top 1');
    final t2 = _tier(map['rank_2'], 'Top 2');
    final t3 = _tier(map['rank_3'], 'Top 3');
    final t4 = _tier(map['rank_4_10'], 'Top 4 ~ 10');
    return GameStarRewardSlots(
      rank1Label: t1.$1,
      rank1Items: t1.$2,
      rank2Label: t2.$1,
      rank2Items: t2.$2,
      rank3Label: t3.$1,
      rank3Items: t3.$2,
      rank4to10Label: t4.$1,
      rank4to10Items: t4.$2,
    );
  }
}

const String kDefaultGameStarRules = '''
Core Gameplay & Points
• How to Participate: Simply play the designated games (shown on this event screen) during the event period to automatically enter the competition.
• Points Conversion: Every 1 Gold Coin won in a designated game = 1 Point.
• Calculation Rules: Points are based only on Gold Coins won in the admin-selected games. Wins from other games, and coins consumed or lost, will not be counted or deducted.

Leaderboard Ranking Rules
• The Ranking tab shows the overall Game Star leaderboard from designated-game wins only.
• Higher points rank higher. If points are the same, the player who reached the score first will take the higher rank.
• Rankings update in real time. The final ranking is based on the list at the end of the event.

Rewards
• Leaderboard Rewards: Players ranked on the Game Star leaderboard will receive exclusive rewards.
• After the overall event concludes, the system will automatically send rewards based on final ranking.
''';

List<String> gameStarGameIdsFromEvent(PartyEvent event) {
  final raw = event.actionConfig['game_star_game_ids'];
  if (raw is! List) return [];
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .take(6)
      .toList();
}

String gameStarRulesFromEvent(PartyEvent event) {
  final rules = (event.actionConfig['rules'] as String?)?.trim() ?? '';
  return rules.isNotEmpty ? rules : kDefaultGameStarRules;
}

GameStarRewardSlots gameStarRewardSlotsFromEvent(PartyEvent event) {
  return GameStarRewardSlots.fromConfig(event.actionConfig);
}

String formatGameStarScore(int score) {
  if (score >= 1000000) return '${(score / 1000000).toStringAsFixed(2)}M';
  if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
  return score.toString();
}

Future<void> refreshGameStarRankings(String eventId) async {
  try {
    await Supabase.instance.client.rpc(
      'refresh_game_star_rankings',
      params: {'p_event_id': eventId},
    );
  } catch (e) {
    debugPrint('[GameStar] refresh failed: $e');
  }
}

Future<PartyEvent?> _loadEvent(String eventId, Ref ref) async {
  final events = await ref.watch(partyEventsProvider.future);
  for (final e in events) {
    if (e.id == eventId) return e;
  }
  final row = await Supabase.instance.client
      .from('party_events')
      .select()
      .eq('id', eventId)
      .maybeSingle();
  if (row == null) return null;
  return PartyEvent.fromMap(Map<String, dynamic>.from(row));
}

final gameStarGamesProvider =
    FutureProvider.family<List<GameStarGameItem>, String>((ref, eventId) async {
      final event = await _loadEvent(eventId, ref);
      if (event == null) return [];
      final ids = gameStarGameIdsFromEvent(event);
      if (ids.isEmpty) return [];

      final response = await Supabase.instance.client
          .from('game_configs')
          .select('id, name, icon_url')
          .inFilter('id', ids);

      final byId = <String, GameStarGameItem>{};
      for (final row in response as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        byId[id] = GameStarGameItem(
          id: id,
          name: m['name']?.toString() ?? 'Game',
          iconUrl: m['icon_url']?.toString() ?? '',
        );
      }
      return ids.map((id) => byId[id]).whereType<GameStarGameItem>().toList();
    });

typedef _GsRankQuery = ({String eventId, String periodKey, String? gameId});

final gameStarTopRankingsProvider =
    FutureProvider.family<List<GameStarUserRank>, _GsRankQuery>((ref, q) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_game_star_rankings',
          params: {
            'p_event_id': q.eventId,
            'p_period_key': q.periodKey,
            'p_limit': 50,
            'p_offset': 0,
            'p_game_id': (q.gameId != null && q.gameId!.isNotEmpty)
                ? q.gameId
                : null,
          },
        );
        if (response is! List) return [];
        return response
            .map(
              (e) => GameStarUserRank.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('[GameStar] rankings failed: $e');
        return [];
      }
    });

typedef _GsFeaturedQuery = ({String eventId, String? gameId});

final gameStarFeaturedWinnerProvider =
    FutureProvider.family<GameStarUserRank?, _GsFeaturedQuery>((ref, q) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_game_star_featured_winner',
          params: {
            'p_event_id': q.eventId,
            'p_game_id': (q.gameId != null && q.gameId!.isNotEmpty)
                ? q.gameId
                : null,
          },
        );
        if (response == null || response is! Map) return null;
        return GameStarUserRank.fromJson(Map<String, dynamic>.from(response));
      } catch (e) {
        debugPrint('[GameStar] featured winner failed: $e');
        return null;
      }
    });

typedef _GsMyRankQuery = ({String eventId, String periodKey, String? gameId});

final myGameStarRankProvider =
    FutureProvider.family<GameStarUserRank?, _GsMyRankQuery>((ref, q) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_my_game_star_rank',
          params: {
            'p_event_id': q.eventId,
            'p_period_key': q.periodKey,
            'p_game_id': (q.gameId != null && q.gameId!.isNotEmpty)
                ? q.gameId
                : null,
          },
        );
        if (response == null || response is! Map) return null;
        final map = Map<String, dynamic>.from(response);
        return GameStarUserRank(
          userId: map['user_id']?.toString() ?? '',
          score: (map['score'] as num?)?.toInt() ?? 0,
          rank: (map['rank'] as num?)?.toInt() ?? 0,
          username: map['username']?.toString(),
          avatarUrl: map['avatar_url']?.toString(),
          shortId: map['short_id']?.toString(),
        );
      } catch (e) {
        debugPrint('[GameStar] my rank failed: $e');
        return null;
      }
    });

typedef _GsHistoryQuery = ({String eventId, String? gameId});

final gameStarHistoryProvider =
    FutureProvider.family<List<GameStarHistoryWeek>, _GsHistoryQuery>((
      ref,
      q,
    ) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_game_star_history',
          params: {
            'p_event_id': q.eventId,
            'p_weeks': 4,
            'p_game_id': (q.gameId != null && q.gameId!.isNotEmpty)
                ? q.gameId
                : null,
          },
        );
        if (response is! List) return [];

        final byWeek = <String, GameStarHistoryWeek>{};
        for (final row in response) {
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          final key = m['period_key']?.toString() ?? '';
          if (key.isEmpty) continue;
          final user = GameStarUserRank.fromJson(m);
          final existing = byWeek[key];
          if (existing == null) {
            byWeek[key] = GameStarHistoryWeek(
              periodKey: key,
              periodStart: DateTime.tryParse(
                m['period_start']?.toString() ?? '',
              ),
              periodEnd: DateTime.tryParse(m['period_end']?.toString() ?? ''),
              top3: [user],
            );
          } else {
            existing.top3.add(user);
          }
        }

        final weeks = byWeek.values.toList()
          ..sort((a, b) => b.periodKey.compareTo(a.periodKey));
        for (final w in weeks) {
          w.top3.sort((a, b) => a.rank.compareTo(b.rank));
        }
        return weeks;
      } catch (e) {
        debugPrint('[GameStar] history failed: $e');
        return [];
      }
    });
