import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

/// The month the BD centre should show, as plain `YYYY-MM`.
///
/// This used to build a half-month id itself — `2026-10-A` before the 16th,
/// `-B` after. Salary moved to whole months, so on the 10th of October it was
/// asking the server for `2026-10-A`, a period that no longer carries any work.
/// Every BD saw a target of \$0 and Work Time 0D/0H.
///
/// The app now names only the month and lets the server resolve which salary
/// period(s) that month is made of, so this cannot drift out of step with the
/// payroll system again.
String currentBdPeriodYm([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// The months a BD can look back over, newest first, as plain `YYYY-MM`.
List<String> listBdSelectablePeriods({int count = 12, DateTime? now}) {
  final anchor = now ?? DateTime.now();
  final out = <String>[];
  var y = anchor.year;
  var m = anchor.month;
  for (var i = 0; i < count; i++) {
    out.add('$y-${m.toString().padLeft(2, '0')}');
    m -= 1;
    if (m < 1) {
      m = 12;
      y -= 1;
    }
  }
  return out;
}

final bdCenterProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String?>((ref, period) async {
      ref.watch(authStateProvider);
      final res = await _supabase.rpc(
        'get_my_bd_center',
        params: {'p_period_yyyy_mm': period ?? currentBdPeriodYm()},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return null;
      return map;
    });

final myBdSettlementHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      ref.watch(authStateProvider);
      final res = await _supabase.rpc(
        'get_my_bd_settlement_history',
        params: {'p_limit': 12},
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return [];
      final rows = map['rows'];
      if (rows is! List) return [];
      return rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });

final countyAdminCenterProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      ref.watch(authStateProvider);
      final res = await _supabase.rpc('get_my_county_admin_center');
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return null;
      return map;
    });

class BdCenterActions {
  static Future<Map<String, dynamic>> activateBd({
    required String targetUserId,
    required String adminStaffCode,
  }) async {
    final res = await _supabase.rpc(
      'county_admin_activate_bd',
      params: {
        'p_target_user_id': targetUserId,
        'p_admin_staff_code': adminStaffCode,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> activateAgency({
    required String agencyRef,
    required String bdStaffCode,
    required String adminStaffCode,
  }) async {
    final res = await _supabase.rpc(
      'county_admin_activate_agency',
      params: {
        'p_agency_ref': agencyRef,
        'p_bd_staff_code': bdStaffCode,
        'p_admin_staff_code': adminStaffCode,
      },
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
