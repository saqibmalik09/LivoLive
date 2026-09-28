import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CpEventCoupleRank {
  const CpEventCoupleRank({
    required this.user1Id,
    required this.user2Id,
    required this.score,
    required this.rank,
    this.user1Name,
    this.user1Avatar,
    this.user2Name,
    this.user2Avatar,
  });

  final String user1Id;
  final String user2Id;
  final int score;
  final int rank;
  final String? user1Name;
  final String? user1Avatar;
  final String? user2Name;
  final String? user2Avatar;

  String get displayNames {
    final a = user1Name?.trim().isNotEmpty == true ? user1Name! : 'User';
    final b = user2Name?.trim().isNotEmpty == true ? user2Name! : 'User';
    return '$a & $b';
  }

  factory CpEventCoupleRank.fromJson(Map<String, dynamic> json) {
    final u1 = json['user1'] is Map
        ? Map<String, dynamic>.from(json['user1'] as Map)
        : <String, dynamic>{};
    final u2 = json['user2'] is Map
        ? Map<String, dynamic>.from(json['user2'] as Map)
        : <String, dynamic>{};
    return CpEventCoupleRank(
      user1Id: json['user_1_id']?.toString() ?? '',
      user2Id: json['user_2_id']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      user1Name: (u1['username'] ?? json['user1_name'])?.toString(),
      user1Avatar: (u1['avatar_url'] ?? json['user1_avatar'])?.toString(),
      user2Name: (u2['username'] ?? json['user2_name'])?.toString(),
      user2Avatar: (u2['avatar_url'] ?? json['user2_avatar'])?.toString(),
    );
  }
}

class CpEventGiftTopItem {
  const CpEventGiftTopItem({
    required this.giftId,
    required this.giftName,
    required this.giftImageUrl,
    required this.totalAmount,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
  });

  final String giftId;
  final String giftName;
  final String giftImageUrl;
  final int totalAmount;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;

  factory CpEventGiftTopItem.fromJson(Map<String, dynamic> json) {
    return CpEventGiftTopItem(
      giftId: json['gift_id']?.toString() ?? '',
      giftName: json['gift_name']?.toString() ?? 'Gift',
      giftImageUrl: json['gift_image_url']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      senderId: json['top_sender_id']?.toString() ?? '',
      senderName: json['top_sender_name']?.toString() ?? 'User',
      senderAvatar: json['top_sender_avatar']?.toString(),
      receiverId: json['top_receiver_id']?.toString() ?? '',
      receiverName: json['top_receiver_name']?.toString() ?? 'User',
      receiverAvatar: json['top_receiver_avatar']?.toString(),
    );
  }
}

class CpEventWeeklySnapshot {
  const CpEventWeeklySnapshot({
    required this.weekIndex,
    required this.periodStart,
    required this.periodEnd,
    this.topGift,
    required this.topCouples,
  });

  final int weekIndex;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final Map<String, dynamic>? topGift;
  final List<CpEventCoupleRank> topCouples;

  factory CpEventWeeklySnapshot.fromJson(Map<String, dynamic> json) {
    final couplesRaw = json['top_couples'];
    final couples = <CpEventCoupleRank>[];
    if (couplesRaw is List) {
      for (final c in couplesRaw) {
        if (c is Map) {
          couples.add(CpEventCoupleRank.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }
    Map<String, dynamic>? gift;
    final g = json['top_gift'];
    if (g is Map) gift = Map<String, dynamic>.from(g);

    DateTime? parseTs(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return CpEventWeeklySnapshot(
      weekIndex: (json['week_index'] as num?)?.toInt() ?? 0,
      periodStart: parseTs(json['period_start']),
      periodEnd: parseTs(json['period_end']),
      topGift: gift,
      topCouples: couples,
    );
  }
}

class CpEventRewardItem {
  const CpEventRewardItem({required this.label, required this.imageUrl});

  final String label;
  final String imageUrl;
}

class CpEventRewardSlots {
  const CpEventRewardSlots({
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
  final List<CpEventRewardItem> rank1Items;
  final String rank2Label;
  final List<CpEventRewardItem> rank2Items;
  final String rank3Label;
  final List<CpEventRewardItem> rank3Items;
  final String rank4to10Label;
  final List<CpEventRewardItem> rank4to10Items;

  static CpEventRewardItem _item(dynamic raw, [String fallback = '']) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      return CpEventRewardItem(
        label: (m['label'] as String?)?.trim().isNotEmpty == true
            ? m['label'] as String
            : fallback,
        imageUrl: (m['image_url'] as String?)?.trim() ?? '',
      );
    }
    return CpEventRewardItem(label: fallback, imageUrl: '');
  }

  static (String, List<CpEventRewardItem>) _tier(
    dynamic raw,
    String fallbackLabel,
  ) {
    if (raw is! Map) {
      return (fallbackLabel, <CpEventRewardItem>[]);
    }
    final m = Map<String, dynamic>.from(raw);
    final label = (m['label'] as String?)?.trim().isNotEmpty == true
        ? m['label'] as String
        : fallbackLabel;
    final items = <CpEventRewardItem>[];
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

  factory CpEventRewardSlots.fromConfig(Map<String, dynamic> config) {
    final raw = config['reward_slots'];
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final t1 = _tier(map['rank_1'], 'Top 1');
    final t2 = _tier(map['rank_2'], 'Top 2');
    final t3 = _tier(map['rank_3'], 'Top 3');
    final t4 = _tier(map['rank_4_10'], 'Top 4 ~ 10');
    return CpEventRewardSlots(
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

String formatCpEventScore(int score) {
  if (score >= 1000000) return '${(score / 1000000).toStringAsFixed(2)}M';
  if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
  return score.toString();
}

Future<void> refreshCpEventRankings(String eventId) async {
  try {
    await Supabase.instance.client.rpc(
      'refresh_cp_event_rankings',
      params: {'p_event_id': eventId},
    );
  } catch (e) {
    debugPrint('[CpEvent] refresh failed: $e');
  }
}

final cpEventTopRankingsProvider =
    FutureProvider.family<List<CpEventCoupleRank>, String>((
      ref,
      eventId,
    ) async {
      try {
        final response = await Supabase.instance.client
            .from('cp_event_rankings')
            .select('''
          *,
          user1:users!user_1_id(username, avatar_url),
          user2:users!user_2_id(username, avatar_url)
        ''')
            .eq('party_event_id', eventId)
            .eq('period_key', 'current')
            .order('rank', ascending: true)
            .limit(50);

        return (response as List)
            .map(
              (e) => CpEventCoupleRank.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('[CpEvent] top rankings failed: $e');
        return [];
      }
    });

final cpEventRankingsPageProvider =
    FutureProvider.family<List<CpEventCoupleRank>, (String, int)>((
      ref,
      params,
    ) async {
      final eventId = params.$1;
      final page = params.$2;
      const pageSize = 20;
      final from = 3 + page * pageSize;
      final to = from + pageSize - 1;

      try {
        final response = await Supabase.instance.client
            .from('cp_event_rankings')
            .select('''
          *,
          user1:users!user_1_id(username, avatar_url),
          user2:users!user_2_id(username, avatar_url)
        ''')
            .eq('party_event_id', eventId)
            .eq('period_key', 'current')
            .order('rank', ascending: true)
            .range(from, to);

        return (response as List)
            .map(
              (e) => CpEventCoupleRank.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('[CpEvent] page rankings failed: $e');
        return [];
      }
    });

final cpEventGiftTopProvider =
    FutureProvider.family<List<CpEventGiftTopItem>, String>((
      ref,
      eventId,
    ) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_cp_event_gift_top',
          params: {'p_event_id': eventId, 'p_limit': 10},
        );
        if (response is! List) return [];
        return response
            .map(
              (e) => CpEventGiftTopItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('[CpEvent] gift top failed: $e');
        return [];
      }
    });

final cpEventWeeklySnapshotsProvider =
    FutureProvider.family<List<CpEventWeeklySnapshot>, String>((
      ref,
      eventId,
    ) async {
      try {
        final response = await Supabase.instance.client.rpc(
          'get_cp_event_weekly_snapshots',
          params: {'p_event_id': eventId, 'p_weeks': 3},
        );
        if (response is! List) return [];
        return response
            .map(
              (e) => CpEventWeeklySnapshot.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('[CpEvent] weekly snapshots failed: $e');
        return [];
      }
    });

final myCpEventRankProvider = FutureProvider.family<CpEventCoupleRank?, String>(
  (ref, eventId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_my_cp_event_rank',
        params: {'p_event_id': eventId},
      );
      if (response == null) return null;
      if (response is! Map) return null;
      final map = Map<String, dynamic>.from(response);
      final rank = (map['rank'] as num?)?.toInt();
      return CpEventCoupleRank(
        user1Id: map['user_1_id']?.toString() ?? '',
        user2Id: map['user_2_id']?.toString() ?? '',
        score: (map['score'] as num?)?.toInt() ?? 0,
        rank: rank ?? 0,
        user1Name: map['user1_name']?.toString(),
        user1Avatar: map['user1_avatar']?.toString(),
        user2Name: map['user2_name']?.toString(),
        user2Avatar: map['user2_avatar']?.toString(),
      );
    } catch (e) {
      debugPrint('[CpEvent] my rank failed: $e');
      return null;
    }
  },
);

CpEventRewardSlots cpEventRewardSlotsFromEvent(PartyEvent event) {
  return CpEventRewardSlots.fromConfig(event.actionConfig);
}
