import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/features/home/presentation/pages/sk_party/sk_party_tiers.dart';

final _supabase = Supabase.instance.client;

class SkHostProgress {
  const SkHostProgress({
    required this.periodId,
    required this.periodStart,
    required this.periodEnd,
    required this.charms,
    required this.workDays,
    required this.workHours,
    required this.level,
    required this.lastPeriodId,
    required this.lastCharms,
    required this.lastWorkDays,
    required this.lastWorkHours,
    required this.lastLevel,
    required this.lastCoinReward,
    required this.lastClaimed,
    required this.canClaim,
    required this.tiers,
    this.nextTier,
    this.rules = '',
  });

  final String periodId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int charms;
  final int workDays;
  final double workHours;
  final int level;
  final SkHostTier? nextTier;
  final String lastPeriodId;
  final int lastCharms;
  final int lastWorkDays;
  final double lastWorkHours;
  final int lastLevel;
  final int lastCoinReward;
  final bool lastClaimed;
  final bool canClaim;
  final List<SkHostTier> tiers;
  final String rules;

  factory SkHostProgress.fromJson(Map<String, dynamic> json) {
    final tiersRaw = json['tiers'];
    final tiers = <SkHostTier>[];
    if (tiersRaw is List) {
      for (final e in tiersRaw) {
        if (e is Map) {
          tiers.add(SkHostTier.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    SkHostTier? next;
    final nextRaw = json['next_tier'];
    if (nextRaw is Map) {
      next = SkHostTier.fromJson(Map<String, dynamic>.from(nextRaw));
    }

    DateTime parseDay(dynamic v, {bool endOfDay = false}) {
      if (v == null) return DateTime.now();
      final s = v.toString();
      final d = DateTime.tryParse(s);
      if (d != null) {
        if (endOfDay && s.length <= 10) {
          return DateTime(d.year, d.month, d.day, 23, 59, 59);
        }
        return d;
      }
      return DateTime.now();
    }

    return SkHostProgress(
      periodId: json['period_id']?.toString() ?? '',
      periodStart: parseDay(json['period_start']),
      periodEnd: parseDay(
        json['period_end_at'] ?? json['period_end'],
        endOfDay: true,
      ),
      charms: (json['charms'] as num?)?.toInt() ?? 0,
      workDays: (json['work_days'] as num?)?.toInt() ?? 0,
      workHours: (json['work_hours'] as num?)?.toDouble() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      nextTier: next,
      lastPeriodId: json['last_period_id']?.toString() ?? '',
      lastCharms: (json['last_charms'] as num?)?.toInt() ?? 0,
      lastWorkDays: (json['last_work_days'] as num?)?.toInt() ?? 0,
      lastWorkHours: (json['last_work_hours'] as num?)?.toDouble() ?? 0,
      lastLevel: (json['last_level'] as num?)?.toInt() ?? 0,
      lastCoinReward: (json['last_coin_reward'] as num?)?.toInt() ?? 0,
      lastClaimed: json['last_claimed'] == true,
      canClaim: json['can_claim'] == true,
      tiers: tiers.isEmpty ? defaultSkHostTiers() : tiers,
      rules: json['rules']?.toString() ?? '',
    );
  }
}

final skHostProgressProvider = FutureProvider.family<SkHostProgress?, String>((
  ref,
  eventId,
) async {
  if (eventId.isEmpty) return null;
  final res = await _supabase.rpc(
    'get_my_sk_host_progress',
    params: {'p_event_id': eventId},
  );
  if (res is! Map) return null;
  final map = Map<String, dynamic>.from(res);
  if (map['success'] == false) {
    throw Exception(map['message']?.toString() ?? 'Failed to load progress');
  }
  return SkHostProgress.fromJson(map);
});

Future<Map<String, dynamic>> claimSkHostPartyReward(String eventId) async {
  final res = await _supabase.rpc(
    'claim_sk_host_party_reward',
    params: {'p_event_id': eventId},
  );
  if (res is Map) return Map<String, dynamic>.from(res);
  return {'success': false, 'message': 'Unexpected response'};
}
