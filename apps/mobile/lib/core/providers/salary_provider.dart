import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

String clientPeriodIdForDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  if (date.day <= 15) return '$y-$m-A';
  return '$y-$m-B';
}

final currentPeriodInfoProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final res = await supabase.rpc('get_current_period_info');
  return Map<String, dynamic>.from(res as Map);
});

final myPeriodStatsProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final period = await ref.watch(currentPeriodInfoProvider.future);
  final periodId = period['period_id'] as String;

  final res = await supabase
      .from('host_period_stats')
      .select()
      .eq('user_id', userId)
      .eq('period_id', periodId)
      .maybeSingle();

  if (res == null) return null;
  return Map<String, dynamic>.from(res);
});

final salaryTiersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final res = await supabase
      .from('salary_tiers')
      .select()
      .eq('is_active', true)
      .order('diamonds_target', ascending: true);
  return List<Map<String, dynamic>>.from(res);
});

final salaryChainConfigProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final res = await supabase
      .from('salary_chain_configs')
      .select()
      .eq('id', 1)
      .maybeSingle();
  return Map<String, dynamic>.from(res ?? {'diamonds_per_dollar': 1000});
});

final mySalaryPayoutsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final res = await supabase
      .from('host_salary_payouts')
      .select()
      .eq('beneficiary_user_id', userId)
      .eq('status', 'paid')
      .order('paid_at', ascending: false)
      .limit(20);

  return List<Map<String, dynamic>>.from(res);
});

final myHostPeriodHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await supabase.rpc(
        'get_my_host_period_history',
        params: {'p_limit': 24},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return [];
      final rows = map['rows'];
      if (rows is! List) return [];
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });

final myAgencySettlementHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, agencyId) async {
      final res = await supabase.rpc(
        'get_my_agency_settlement_history',
        params: {'p_agency_id': agencyId, 'p_limit': 24},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return [];
      final rows = map['rows'];
      if (rows is! List) return [];
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });

Map<String, dynamic>? matchSalaryTier(
  List<Map<String, dynamic>> tiers,
  Map<String, dynamic>? stats,
) {
  if (stats == null || tiers.isEmpty) return null;
  final diamonds = stats['total_diamonds'] as int? ?? 0;
  final hours = ((stats['total_on_mic_seconds'] as int? ?? 0) / 3600).floor();
  final days = stats['valid_days'] as int? ?? 0;

  Map<String, dynamic>? best;
  for (final tier in tiers) {
    final dTarget = tier['diamonds_target'] as int? ?? 0;
    final hTarget = tier['hours_target'] as int? ?? 0;
    final dayTarget = tier['days_target'] as int? ?? 0;
    if (diamonds >= dTarget && hours >= hTarget && days >= dayTarget) {
      best = tier;
    }
  }
  return best;
}

Map<String, dynamic>? nextSalaryTier(
  List<Map<String, dynamic>> tiers,
  Map<String, dynamic>? stats,
) {
  final diamonds = stats?['total_diamonds'] as int? ?? 0;
  for (final tier in tiers) {
    if (diamonds < (tier['diamonds_target'] as int? ?? 0)) return tier;
  }
  return null;
}
