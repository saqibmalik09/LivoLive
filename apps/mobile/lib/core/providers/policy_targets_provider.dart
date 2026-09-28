import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

final hostPeriodTargetProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String?>((ref, periodId) async {
      ref.watch(authStateProvider);
      final res = await _supabase.rpc(
        'get_host_period_target',
        params: {'p_period_id': periodId},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return null;
      return map;
    });

final agencyPeriodTargetsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, ({String agencyId, String? periodId})>((
      ref,
      args,
    ) async {
      ref.watch(authStateProvider);
      final res = await _supabase.rpc(
        'get_agency_period_targets',
        params: {'p_agency_id': args.agencyId, 'p_period_id': args.periodId},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return null;
      return map;
    });

final agencySalaryLevelsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final res = await _supabase
          .from('agency_salary_level_configs')
          .select()
          .eq('is_active', true)
          .order('level', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    });
