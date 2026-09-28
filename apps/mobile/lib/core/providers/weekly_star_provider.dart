import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyStarUserRank {
  const WeeklyStarUserRank({
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

  factory WeeklyStarUserRank.fromJson(Map<String, dynamic> json) {
    return WeeklyStarUserRank(
      userId: (json['user_id'] ?? '').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      shortId: (json['short_id'] ?? json['shortId'])?.toString(),
    );
  }
}

class WeeklyStarGiftItem {
  const WeeklyStarGiftItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.priceCoins,
    required this.points,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int priceCoins;
  final int points;
}

class WeeklyStarGiftConfig {
  const WeeklyStarGiftConfig({required this.giftId, required this.points});

  final String giftId;
  final int points;
}

List<WeeklyStarGiftConfig> weeklyStarGiftConfigsFromEvent(PartyEvent event) {
  final cfg = event.actionConfig;
  final raw = cfg['weekly_star_gifts'];
  if (raw is List && raw.isNotEmpty) {
    final out = <WeeklyStarGiftConfig>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = (m['gift_id'] ?? m['id'])?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      final pts = (m['points'] as num?)?.toInt() ?? 0;
      out.add(WeeklyStarGiftConfig(giftId: id, points: pts));
      if (out.length >= 4) break;
    }
    if (out.isNotEmpty) return out;
  }

  final ids = <WeeklyStarGiftConfig>[];
  final legacy = cfg['weekly_star_gift_ids'];
  if (legacy is List) {
    for (final g in legacy) {
      final id = g?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      ids.add(WeeklyStarGiftConfig(giftId: id, points: 0));
      if (ids.length >= 4) break;
    }
  }
  return ids;
}

List<String> weeklyStarGiftIdsFromEvent(PartyEvent event) {
  return weeklyStarGiftConfigsFromEvent(event).map((e) => e.giftId).toList();
}

class WeeklyStarRewardItem {
  const WeeklyStarRewardItem({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;
}

class WeeklyStarRewardSlots {
  const WeeklyStarRewardSlots({
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
  final List<WeeklyStarRewardItem> rank1Items;
  final String rank2Label;
  final List<WeeklyStarRewardItem> rank2Items;
  final String rank3Label;
  final List<WeeklyStarRewardItem> rank3Items;
  final String rank4to10Label;
  final List<WeeklyStarRewardItem> rank4to10Items;

  static WeeklyStarRewardItem _item(dynamic raw, [String fallback = '']) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return WeeklyStarRewardItem(
        label: (m['label'] as String?)?.trim().isNotEmpty == true
            ? m['label'] as String
            : fallback,
        imageUrl: (m['image_url'] as String?)?.trim() ?? '',
      );
    }
    return WeeklyStarRewardItem(label: fallback, imageUrl: '');
  }

  static (String, List<WeeklyStarRewardItem>) _tier(
    dynamic raw,
    String fallbackLabel,
  ) {
    if (raw is! Map) {
      return (fallbackLabel, <WeeklyStarRewardItem>[]);
    }
    final m = Map<String, dynamic>.from(raw);
    final label = (m['label'] as String?)?.trim().isNotEmpty == true
        ? m['label'] as String
        : fallbackLabel;
    final items = <WeeklyStarRewardItem>[];
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

  factory WeeklyStarRewardSlots.fromConfig(Map<String, dynamic> config) {
    final raw = config['reward_slots'];
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final t1 = _tier(map['rank_1'], 'Top 1');
    final t2 = _tier(map['rank_2'], 'Top 2');
    final t3 = _tier(map['rank_3'], 'Top 3');
    final t4 = _tier(map['rank_4_10'], 'Top 4 ~ 10');
    return WeeklyStarRewardSlots(
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

const String kDefaultWeeklyStarRules = '''
1. Only the specified gifts received will be counted for points. All other gifts are invalid.
2. Receiving a specified gift awards the points shown under that gift.
3. The points are updated in real time. The final ranking is based on the list at the end of the event.
4. After the event ends, the system will automatically send the rewards.
''';

String weeklyStarRulesFromEvent(PartyEvent event) {
  final rules = (event.actionConfig['rules'] as String?)?.trim() ?? '';
  return rules.isNotEmpty ? rules : kDefaultWeeklyStarRules;
}

WeeklyStarRewardSlots weeklyStarRewardSlotsFromEvent(PartyEvent event) {
  return WeeklyStarRewardSlots.fromConfig(event.actionConfig);
}

String formatWeeklyStarScore(int score) {
  if (score >= 1000000) return '${(score / 1000000).toStringAsFixed(2)}M';
  if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
  return score.toString();
}

Future<void> refreshWeeklyStarRankings(String eventId) async {
  try {
    await Supabase.instance.client.rpc(
      'refresh_weekly_star_rankings',
      params: {'p_event_id': eventId},
    );
  } catch (e) {
    debugPrint('[WeeklyStar] refresh failed: $e');
  }
}

final weeklyStarGiftsProvider =
    FutureProvider.family<List<WeeklyStarGiftItem>, String>((
      ref,
      eventId,
    ) async {
      final events = await ref.watch(partyEventsProvider.future);
      PartyEvent? event;
      for (final e in events) {
        if (e.id == eventId) {
          event = e;
          break;
        }
      }
      if (event == null) {
        final row = await Supabase.instance.client
            .from('party_events')
            .select('action_config')
            .eq('id', eventId)
            .maybeSingle();
        if (row == null) return [];
        event = PartyEvent(
          id: eventId,
          title: '',
          subtitle: '',
          bannerUrl: '',
          eventKind: PartyEventKind.weeklyStarNative,
          actionConfig: row['action_config'] is Map
              ? Map<String, dynamic>.from(row['action_config'] as Map)
              : {},
          isActive: true,
          priority: 0,
        );
      }

      final configs = weeklyStarGiftConfigsFromEvent(event);
      if (configs.isEmpty) return [];

      final ids = configs.map((c) => c.giftId).toList();
      final pointsById = {for (final c in configs) c.giftId: c.points};

      final response = await Supabase.instance.client
          .from('shop_items')
          .select('id, name, image_url, price_coins')
          .inFilter('id', ids);

      final byId = <String, WeeklyStarGiftItem>{};
      for (final row in response as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final price = (m['price_coins'] as num?)?.toInt() ?? 0;
        final pts = pointsById[id] ?? 0;
        byId[id] = WeeklyStarGiftItem(
          id: id,
          name: m['name']?.toString() ?? 'Gift',
          imageUrl: m['image_url']?.toString() ?? '',
          priceCoins: price,
          points: pts > 0 ? pts : price,
        );
      }
      return ids.map((id) => byId[id]).whereType<WeeklyStarGiftItem>().toList();
    });

typedef _RankQuery = ({String eventId, String periodKey});

final weeklyStarTopRankingsProvider =
    FutureProvider.family<List<WeeklyStarUserRank>, _RankQuery>((ref, q) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_weekly_star_rankings',
          params: {
            'p_event_id': q.eventId,
            'p_period_key': q.periodKey,
            'p_limit': 50,
            'p_offset': 0,
          },
        );
        if (response is! List) return [];
        return response
            .map(
              (e) => WeeklyStarUserRank.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('[WeeklyStar] rankings failed: $e');
        return [];
      }
    });

final weeklyStarThisWeekProvider =
    FutureProvider.family<List<WeeklyStarUserRank>, String>((ref, eventId) {
      return ref.watch(
        weeklyStarTopRankingsProvider((
          eventId: eventId,
          periodKey: 'current',
        )).future,
      );
    });

final weeklyStarLastWeekProvider =
    FutureProvider.family<List<WeeklyStarUserRank>, String>((ref, eventId) {
      return ref.watch(
        weeklyStarTopRankingsProvider((
          eventId: eventId,
          periodKey: 'last',
        )).future,
      );
    });

final weeklyStarLastWeekWinnerProvider =
    FutureProvider.family<WeeklyStarUserRank?, String>((ref, eventId) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_weekly_star_last_week_winner',
          params: {'p_event_id': eventId},
        );
        if (response == null) return null;
        if (response is! Map) return null;
        return WeeklyStarUserRank.fromJson(Map<String, dynamic>.from(response));
      } catch (e) {
        debugPrint('[WeeklyStar] last week winner failed: $e');
        return null;
      }
    });

typedef _MyRankQuery = ({String eventId, String periodKey});

final myWeeklyStarRankProvider =
    FutureProvider.family<WeeklyStarUserRank?, _MyRankQuery>((ref, q) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_my_weekly_star_rank',
          params: {'p_event_id': q.eventId, 'p_period_key': q.periodKey},
        );
        if (response == null) return null;
        if (response is! Map) return null;
        final map = Map<String, dynamic>.from(response);
        return WeeklyStarUserRank(
          userId: map['user_id']?.toString() ?? '',
          score: (map['score'] as num?)?.toInt() ?? 0,
          rank: (map['rank'] as num?)?.toInt() ?? 0,
          username: map['username']?.toString(),
          avatarUrl: map['avatar_url']?.toString(),
          shortId: map['short_id']?.toString(),
        );
      } catch (e) {
        debugPrint('[WeeklyStar] my rank failed: $e');
        return null;
      }
    });

Future<List<WeeklyStarUserRank>> fetchWeeklyStarRankingsPage({
  required String eventId,
  required String periodKey,
  required int limit,
  required int offset,
}) async {
  try {
    final response = await Supabase.instance.client.rpc(
      'get_weekly_star_rankings',
      params: {
        'p_event_id': eventId,
        'p_period_key': periodKey,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    if (response is! List) return [];
    return response
        .map(
          (e) =>
              WeeklyStarUserRank.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  } catch (e) {
    debugPrint('[WeeklyStar] page fetch failed: $e');
    return [];
  }
}
