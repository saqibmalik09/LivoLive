import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MicDailyRewardLevelInfo {
  const MicDailyRewardLevelInfo({
    required this.id,
    required this.requiredSeconds,
    required this.sortOrder,
    required this.rewardType,
    required this.coinAmount,
    required this.title,
    required this.imageUrl,
    required this.isActive,
    required this.claimed,
    required this.canClaim,
    this.shopItemId,
    this.durationDays,
  });

  final String id;
  final int requiredSeconds;
  final int sortOrder;
  final String rewardType;
  final int coinAmount;
  final String title;
  final String imageUrl;
  final String? shopItemId;
  final int? durationDays;
  final bool isActive;
  final bool claimed;
  final bool canClaim;

  int get requiredMinutes => (requiredSeconds / 60).ceil();

  factory MicDailyRewardLevelInfo.fromMap(Map<String, dynamic> map) {
    return MicDailyRewardLevelInfo(
      id: map['id']?.toString() ?? '',
      requiredSeconds: (map['required_seconds'] as num?)?.toInt() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      rewardType: map['reward_type']?.toString().trim().isNotEmpty == true
          ? map['reward_type'].toString().trim()
          : 'coins',
      coinAmount: (map['coin_amount'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString().trim() ?? '',
      imageUrl: map['image_url']?.toString().trim() ?? '',
      shopItemId: map['shop_item_id']?.toString(),
      durationDays: (map['duration_days'] as num?)?.toInt(),
      isActive: map['is_active'] as bool? ?? true,
      claimed: map['claimed'] as bool? ?? false,
      canClaim: map['can_claim'] as bool? ?? false,
    );
  }
}

class MicDailyRewardProgress {
  const MicDailyRewardProgress({
    required this.seconds,
    required this.periodKey,
    required this.secondsRemaining,
    required this.levels,
    required this.rules,
  });

  final int seconds;
  final String periodKey;
  final int secondsRemaining;
  final List<MicDailyRewardLevelInfo> levels;
  final List<String> rules;

  int get minutes => seconds ~/ 60;

  MicDailyRewardLevelInfo? get nextTarget {
    for (final l in levels) {
      if (!l.claimed && seconds < l.requiredSeconds) return l;
    }
    for (final l in levels.reversed) {
      if (!l.claimed) return l;
    }
    return levels.isEmpty ? null : levels.last;
  }

  double progressRatioFor(MicDailyRewardLevelInfo? level) {
    if (level == null || level.requiredSeconds <= 0) return 0;
    return (seconds / level.requiredSeconds).clamp(0.0, 1.0);
  }

  factory MicDailyRewardProgress.empty() {
    return const MicDailyRewardProgress(
      seconds: 0,
      periodKey: '',
      secondsRemaining: 0,
      levels: [],
      rules: [],
    );
  }

  factory MicDailyRewardProgress.fromMap(Map<String, dynamic> map) {
    final levelsRaw = map['levels'];
    final levels = <MicDailyRewardLevelInfo>[];
    if (levelsRaw is List) {
      for (final e in levelsRaw) {
        if (e is Map) {
          levels.add(
            MicDailyRewardLevelInfo.fromMap(Map<String, dynamic>.from(e)),
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

    return MicDailyRewardProgress(
      seconds: (map['seconds'] as num?)?.toInt() ?? 0,
      periodKey: map['period_key']?.toString() ?? '',
      secondsRemaining: (map['seconds_remaining'] as num?)?.toInt() ?? 0,
      levels: levels,
      rules: rules,
    );
  }
}

final micDailyRewardProgressProvider = FutureProvider<MicDailyRewardProgress>((
  ref,
) async {
  try {
    final res = await Supabase.instance.client.rpc(
      'get_mic_daily_reward_progress',
    );
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      if (map['success'] == false) {
        debugPrint('[micDaily] progress failed: ${map['message']}');
        return MicDailyRewardProgress.empty();
      }
      return MicDailyRewardProgress.fromMap(map);
    }
    return MicDailyRewardProgress.empty();
  } catch (e) {
    debugPrint('[micDaily] progress error: $e');
    return MicDailyRewardProgress.empty();
  }
});

class MicDailyRewardService {
  static Future<Map<String, dynamic>> claim({required String levelId}) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'claim_mic_daily_reward',
        params: {'p_level_id': levelId},
      );
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'message': 'Unexpected response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
