import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyRoomRewardLevelInfo {
  const WeeklyRoomRewardLevelInfo({
    required this.level,
    required this.requiredPoints,
    required this.coinReward,
    required this.rewardType,
    required this.title,
    required this.imageUrl,
    required this.isActive,
    required this.targetReached,
    required this.claimed,
    required this.canClaim,
    required this.expired,
    this.shopItemId,
    this.durationDays,
  });

  final int level;
  final int requiredPoints;
  final int coinReward;
  final String rewardType;
  final String title;
  final String imageUrl;
  final String? shopItemId;
  final int? durationDays;
  final bool isActive;
  final bool targetReached;
  final bool claimed;
  final bool canClaim;
  final bool expired;

  factory WeeklyRoomRewardLevelInfo.fromMap(Map<String, dynamic> map) {
    return WeeklyRoomRewardLevelInfo(
      level: (map['level'] as num?)?.toInt() ?? 1,
      requiredPoints: (map['required_points'] as num?)?.toInt() ?? 0,
      coinReward: (map['coin_reward'] as num?)?.toInt() ?? 0,
      rewardType: map['reward_type']?.toString().trim().isNotEmpty == true
          ? map['reward_type'].toString().trim()
          : 'coins',
      title: map['title']?.toString().trim() ?? '',
      imageUrl: map['image_url']?.toString().trim() ?? '',
      shopItemId: map['shop_item_id']?.toString(),
      durationDays: (map['duration_days'] as num?)?.toInt(),
      isActive: map['is_active'] as bool? ?? true,
      targetReached: map['target_reached'] as bool? ?? false,
      claimed: map['claimed'] as bool? ?? false,
      canClaim: map['can_claim'] as bool? ?? false,
      expired: map['expired'] as bool? ?? false,
    );
  }
}

class WeeklyRoomRewardProgress {
  const WeeklyRoomRewardProgress({
    required this.charm,
    required this.claimCharm,
    required this.isOwner,
    required this.periodKey,
    required this.claimPeriodKey,
    required this.weekStart,
    required this.weekEnd,
    required this.claimDeadline,
    required this.inClaimWindow,
    required this.remainingSeconds,
    required this.levels,
    required this.rules,
  });

  final int charm;
  final int claimCharm;
  final bool isOwner;
  final String periodKey;
  final String claimPeriodKey;
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final DateTime? claimDeadline;
  final bool inClaimWindow;
  final int remainingSeconds;
  final List<WeeklyRoomRewardLevelInfo> levels;
  final List<String> rules;

  factory WeeklyRoomRewardProgress.empty() {
    return const WeeklyRoomRewardProgress(
      charm: 0,
      claimCharm: 0,
      isOwner: false,
      periodKey: '',
      claimPeriodKey: '',
      weekStart: null,
      weekEnd: null,
      claimDeadline: null,
      inClaimWindow: false,
      remainingSeconds: 0,
      levels: [],
      rules: [],
    );
  }

  factory WeeklyRoomRewardProgress.fromMap(Map<String, dynamic> map) {
    DateTime? parseTs(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    final levelsRaw = map['levels'];
    final levels = <WeeklyRoomRewardLevelInfo>[];
    if (levelsRaw is List) {
      for (final e in levelsRaw) {
        if (e is Map) {
          levels.add(
            WeeklyRoomRewardLevelInfo.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    final rulesRaw = map['rules'];
    final rules = <String>[];
    if (rulesRaw is List) {
      for (final e in rulesRaw) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) rules.add(s);
      }
    }

    return WeeklyRoomRewardProgress(
      charm: (map['charm'] as num?)?.toInt() ?? 0,
      claimCharm: (map['claim_charm'] as num?)?.toInt() ?? 0,
      isOwner: map['is_owner'] as bool? ?? false,
      periodKey: map['period_key']?.toString() ?? '',
      claimPeriodKey: map['claim_period_key']?.toString() ?? '',
      weekStart: parseTs(map['week_start']),
      weekEnd: parseTs(map['week_end']),
      claimDeadline: parseTs(map['claim_deadline']),
      inClaimWindow: map['in_claim_window'] as bool? ?? false,
      remainingSeconds: (map['remaining_seconds'] as num?)?.toInt() ?? 0,
      levels: levels,
      rules: rules,
    );
  }

  String formatRemaining() {
    var sec = remainingSeconds;
    if (sec < 0) sec = 0;
    final days = sec ~/ 86400;
    final hours = (sec % 86400) ~/ 3600;
    final mins = (sec % 3600) ~/ 60;
    final secs = sec % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (days > 0) return '${days}d $hh:$mm:$ss';
    return '$hh:$mm:$ss';
  }

  bool get hasClaimedThisPeriod => levels.any((l) => l.claimed);

  WeeklyRoomRewardLevelInfo? get claimableLevel {
    for (final l in levels) {
      if (l.canClaim) return l;
    }
    return null;
  }

  int? get highlightLevel {
    int? maxReachedThisWeek;
    for (final l in levels) {
      if (!l.isActive) continue;
      if (l.targetReached) maxReachedThisWeek = l.level;
    }

    if (hasClaimedThisPeriod || !inClaimWindow) {
      return maxReachedThisWeek ?? currentWeekFocusLevel?.level;
    }

    final claimable = claimableLevel;
    if (claimable != null) return claimable.level;

    int? maxClaimCharm;
    for (final l in levels) {
      if (!l.isActive) continue;
      if (claimCharm >= l.requiredPoints) maxClaimCharm = l.level;
    }
    return maxClaimCharm ?? maxReachedThisWeek ?? currentWeekFocusLevel?.level;
  }

  WeeklyRoomRewardLevelInfo? get currentWeekFocusLevel {
    final active = levels.where((l) => l.isActive).toList();
    if (active.isEmpty) return null;
    for (final l in active) {
      if (charm < l.requiredPoints) return l;
    }
    return active.last;
  }
}

class WeeklyRoomRewardClaimRecord {
  const WeeklyRoomRewardClaimRecord({
    required this.id,
    required this.level,
    required this.periodKey,
    required this.coinAmount,
    required this.claimedAt,
  });

  final String id;
  final int level;
  final String periodKey;
  final int coinAmount;
  final DateTime? claimedAt;

  factory WeeklyRoomRewardClaimRecord.fromMap(Map<String, dynamic> map) {
    DateTime? ts;
    final raw = map['claimed_at'];
    if (raw is String && raw.isNotEmpty) ts = DateTime.tryParse(raw);
    return WeeklyRoomRewardClaimRecord(
      id: map['id']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 1,
      periodKey: map['period_key']?.toString() ?? '',
      coinAmount: (map['coin_amount'] as num?)?.toInt() ?? 0,
      claimedAt: ts,
    );
  }
}

final weeklyRoomRewardProgressProvider =
    FutureProvider.family<WeeklyRoomRewardProgress, String>((
      ref,
      roomId,
    ) async {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_weekly_room_reward_progress',
          params: {'p_room_id': roomId},
        );
        if (res is Map) {
          final map = Map<String, dynamic>.from(res);
          if (map['success'] == false) {
            debugPrint('[weeklyRoomReward] progress failed: ${map['message']}');
            return WeeklyRoomRewardProgress.empty();
          }
          return WeeklyRoomRewardProgress.fromMap(map);
        }
        return WeeklyRoomRewardProgress.empty();
      } catch (e) {
        debugPrint('[weeklyRoomReward] progress error: $e');
        return WeeklyRoomRewardProgress.empty();
      }
    });

final weeklyRoomRewardClaimsProvider =
    FutureProvider.family<List<WeeklyRoomRewardClaimRecord>, String>((
      ref,
      roomId,
    ) async {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_weekly_room_reward_claims',
          params: {'p_room_id': roomId},
        );
        if (res is Map) {
          final map = Map<String, dynamic>.from(res);
          final raw = map['claims'];
          if (raw is! List) return [];
          return raw
              .whereType<Map>()
              .map(
                (e) => WeeklyRoomRewardClaimRecord.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
        }
        return [];
      } catch (e) {
        debugPrint('[weeklyRoomReward] claims error: $e');
        return [];
      }
    });

final hostedRoomIdProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  if (userId.isEmpty) return null;
  try {
    final res = await Supabase.instance.client
        .from('rooms')
        .select('id')
        .eq('host_id', userId)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    final id = res['id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  } catch (e) {
    debugPrint('[weeklyRoomReward] hosted room lookup error: $e');
    return null;
  }
});

class WeeklyRoomRewardService {
  static Future<Map<String, dynamic>> claim({
    required String roomId,
    required int level,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'claim_weekly_room_reward',
        params: {'p_room_id': roomId, 'p_level': level},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'message': 'Unexpected response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
