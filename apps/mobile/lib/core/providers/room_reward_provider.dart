import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomRewardLevelInfo {
  const RoomRewardLevelInfo({
    required this.level,
    required this.requiredPoints,
    required this.isActive,
    required this.claimed,
    required this.forfeited,
    required this.canOpen,
    required this.claimSecondsRemaining,
    this.claimExpiresAt,
  });

  final int level;
  final int requiredPoints;
  final bool isActive;
  final bool claimed;
  final bool forfeited;
  final bool canOpen;
  final int claimSecondsRemaining;
  final DateTime? claimExpiresAt;

  int liveClaimSecondsRemaining([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (claimExpiresAt != null) {
      final secs = claimExpiresAt!.difference(n).inSeconds;
      return secs > 0 ? secs : 0;
    }
    return claimSecondsRemaining.clamp(0, 120);
  }

  factory RoomRewardLevelInfo.fromMap(Map<String, dynamic> map) {
    DateTime? expires;
    final raw = map['claim_expires_at'];
    if (raw is String && raw.isNotEmpty) {
      expires = DateTime.tryParse(raw)?.toLocal();
    }
    return RoomRewardLevelInfo(
      level: (map['level'] as num?)?.toInt() ?? 1,
      requiredPoints: (map['required_points'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      claimed: map['claimed'] as bool? ?? false,
      forfeited: map['forfeited'] as bool? ?? false,
      canOpen: map['can_open'] as bool? ?? false,
      claimSecondsRemaining:
          (map['claim_seconds_remaining'] as num?)?.toInt() ?? 0,
      claimExpiresAt: expires,
    );
  }
}

class RoomRewardItemInfo {
  const RoomRewardItemInfo({
    required this.id,
    required this.level,
    required this.title,
    required this.imageUrl,
    required this.rewardType,
    required this.coinAmount,
    required this.weight,
    required this.sortOrder,
    required this.isFeatured,
    this.shopItemId,
  });

  final String id;
  final int level;
  final String title;
  final String imageUrl;
  final String rewardType;
  final int coinAmount;
  final int weight;
  final int sortOrder;
  final bool isFeatured;
  final String? shopItemId;

  factory RoomRewardItemInfo.fromMap(Map<String, dynamic> map) {
    return RoomRewardItemInfo(
      id: map['id']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 1,
      title: (map['title'] as String?)?.trim() ?? '',
      imageUrl: (map['image_url'] as String?)?.trim() ?? '',
      rewardType: (map['reward_type'] as String?)?.trim() ?? 'coins',
      coinAmount: (map['coin_amount'] as num?)?.toInt() ?? 0,
      weight: (map['weight'] as num?)?.toInt() ?? 1,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isFeatured: map['is_featured'] as bool? ?? false,
      shopItemId: map['shop_item_id']?.toString(),
    );
  }
}

class RoomRewardProgress {
  const RoomRewardProgress({
    required this.energy,
    required this.currentLevel,
    required this.claimedLevels,
    required this.forfeitedLevels,
    required this.levels,
    required this.items,
    required this.rules,
  });

  final int energy;
  final int currentLevel;
  final List<int> claimedLevels;
  final List<int> forfeitedLevels;
  final List<RoomRewardLevelInfo> levels;
  final List<RoomRewardItemInfo> items;
  final List<String> rules;

  RoomRewardLevelInfo? levelInfo(int level) {
    for (final l in levels) {
      if (l.level == level) return l;
    }
    return null;
  }

  RoomRewardLevelInfo? get openClaimLevel {
    for (final l in levels) {
      if (l.canOpen && l.liveClaimSecondsRemaining() > 0) return l;
    }
    return null;
  }

  int get maxLevel {
    var max = 1;
    for (final l in levels) {
      if (l.level > max) max = l.level;
    }
    return max;
  }

  int get focusLevel {
    final open = openClaimLevel;
    if (open != null) return open.level.clamp(1, maxLevel);

    var unlocked = 0;
    for (final l in levels) {
      if (!l.isActive) continue;
      if (energy >= l.requiredPoints && l.level > unlocked) {
        unlocked = l.level;
      }
    }
    if (unlocked > 0) return unlocked.clamp(1, maxLevel);

    final fromApi = currentLevel.clamp(1, maxLevel);
    if (fromApi > 0) return fromApi;
    return 1;
  }

  List<RoomRewardItemInfo> itemsForLevel(int level) {
    return items.where((i) => i.level == level).toList();
  }

  double progressForLevel(int level) {
    final info = levelInfo(level);
    if (info == null || info.requiredPoints <= 0) return 0;
    return (energy / info.requiredPoints).clamp(0.0, 1.0);
  }

  factory RoomRewardProgress.empty() {
    return const RoomRewardProgress(
      energy: 0,
      currentLevel: 1,
      claimedLevels: [],
      forfeitedLevels: [],
      levels: [],
      items: [],
      rules: [],
    );
  }

  factory RoomRewardProgress.fromMap(Map<String, dynamic> map) {
    final claimedRaw = map['claimed_levels'];
    final claimed = <int>[];
    if (claimedRaw is List) {
      for (final e in claimedRaw) {
        if (e is num) claimed.add(e.toInt());
      }
    }

    final forfeitedRaw = map['forfeited_levels'];
    final forfeited = <int>[];
    if (forfeitedRaw is List) {
      for (final e in forfeitedRaw) {
        if (e is num) forfeited.add(e.toInt());
      }
    }

    final levelsRaw = map['levels'];
    final levels = <RoomRewardLevelInfo>[];
    if (levelsRaw is List) {
      for (final e in levelsRaw) {
        if (e is Map) {
          levels.add(RoomRewardLevelInfo.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    final itemsRaw = map['items'];
    final items = <RoomRewardItemInfo>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) {
          items.add(RoomRewardItemInfo.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    final rulesRaw = map['rules'];
    final rules = <String>[];
    if (rulesRaw is List) {
      for (final e in rulesRaw) {
        if (e != null && e.toString().trim().isNotEmpty) {
          rules.add(e.toString().trim());
        }
      }
    }

    return RoomRewardProgress(
      energy: (map['energy'] as num?)?.toInt() ?? 0,
      currentLevel: (map['current_level'] as num?)?.toInt() ?? 1,
      claimedLevels: claimed,
      forfeitedLevels: forfeited,
      levels: levels,
      items: items,
      rules: rules,
    );
  }
}

class RoomRewardClaimRecord {
  const RoomRewardClaimRecord({
    required this.id,
    required this.level,
    required this.createdAt,
    required this.snapshot,
  });

  final String id;
  final int level;
  final DateTime? createdAt;
  final Map<String, dynamic> snapshot;

  String get title => snapshot['title']?.toString() ?? 'Reward';
  String get imageUrl => snapshot['image_url']?.toString() ?? '';
  String get rewardType => snapshot['reward_type']?.toString() ?? '';
  int get coinAmount => (snapshot['coin_amount'] as num?)?.toInt() ?? 0;

  factory RoomRewardClaimRecord.fromMap(Map<String, dynamic> map) {
    DateTime? ts;
    final raw = map['created_at'];
    if (raw is String && raw.isNotEmpty) {
      ts = DateTime.tryParse(raw);
    }
    final snap = map['reward_snapshot'];
    return RoomRewardClaimRecord(
      id: map['id']?.toString() ?? '',
      level: (map['level'] as num?)?.toInt() ?? 1,
      createdAt: ts,
      snapshot: snap is Map
          ? Map<String, dynamic>.from(snap)
          : <String, dynamic>{},
    );
  }
}

final roomRewardProgressProvider =
    FutureProvider.family<RoomRewardProgress, String>((ref, roomId) async {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_room_reward_progress',
          params: {'p_room_id': roomId},
        );
        if (res is Map) {
          final map = Map<String, dynamic>.from(res);
          if (map['success'] == false) {
            debugPrint('[roomReward] progress failed: ${map['message']}');
            return RoomRewardProgress.empty();
          }
          return RoomRewardProgress.fromMap(map);
        }
        return RoomRewardProgress.empty();
      } catch (e) {
        debugPrint('[roomReward] progress error: $e');
        return RoomRewardProgress.empty();
      }
    });

final roomRewardClaimsProvider =
    FutureProvider.family<List<RoomRewardClaimRecord>, String>((
      ref,
      roomId,
    ) async {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_room_reward_claims',
          params: {'p_room_id': roomId},
        );
        if (res is Map) {
          final map = Map<String, dynamic>.from(res);
          final claimsRaw = map['claims'];
          if (claimsRaw is! List) return [];
          return claimsRaw
              .whereType<Map>()
              .map(
                (e) =>
                    RoomRewardClaimRecord.fromMap(Map<String, dynamic>.from(e)),
              )
              .toList();
        }
        return [];
      } catch (e) {
        debugPrint('[roomReward] claims error: $e');
        return [];
      }
    });

class RoomRewardService {
  static Future<Map<String, dynamic>> openBox({
    required String roomId,
    required int level,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'open_room_reward_box',
        params: {'p_room_id': roomId, 'p_level': level},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'message': 'Unexpected response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
