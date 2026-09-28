import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class WithdrawalConfig {
  final String id;
  final double feePercent;
  final double minAmount;
  final List<int> allowedDays;
  final int timezoneOffsetHours;

  const WithdrawalConfig({
    required this.id,
    required this.feePercent,
    required this.minAmount,
    required this.allowedDays,
    required this.timezoneOffsetHours,
  });

  factory WithdrawalConfig.fromMap(Map<String, dynamic> map) {
    final days = map['allowed_days'];
    return WithdrawalConfig(
      id: map['id'] as String,
      feePercent: (map['fee_percent'] as num?)?.toDouble() ?? 0,
      minAmount: (map['min_amount'] as num?)?.toDouble() ?? 1,
      allowedDays: days is List
          ? days.map((e) => (e as num).toInt()).toList()
          : const [1, 2, 3, 4, 5, 16, 17, 18, 19, 20],
      timezoneOffsetHours: (map['timezone_offset_hours'] as num?)?.toInt() ?? 3,
    );
  }

  bool get isWithdrawDayToday {
    final utc = DateTime.now().toUtc();
    final local = utc.add(Duration(hours: timezoneOffsetHours));
    return allowedDays.contains(local.day);
  }
}

final withdrawalConfigProvider = FutureProvider<WithdrawalConfig?>((ref) async {
  final res = await _supabase
      .from('withdrawal_configs')
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (res == null) return null;
  return WithdrawalConfig.fromMap(Map<String, dynamic>.from(res));
});

class UserPaymentMethod {
  final String id;
  final String method;
  final String name;
  final String address;

  const UserPaymentMethod({
    required this.id,
    required this.method,
    required this.name,
    required this.address,
  });

  factory UserPaymentMethod.fromMap(Map<String, dynamic> map) {
    return UserPaymentMethod(
      id: map['id'] as String,
      method: map['method'] as String? ?? '',
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
    );
  }
}

final userPaymentMethodsProvider =
    FutureProvider.autoDispose<List<UserPaymentMethod>>((ref) async {
      final user = ref.watch(authStateProvider).value?.session?.user;
      if (user == null) return [];

      final res = await _supabase
          .from('user_payment_methods')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (res as List)
          .map((e) => UserPaymentMethod.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    });

final systemPaymentMethodOptionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
      const fallback = ['Bank', 'JazzCash', 'EasyPaisa', 'USDT'];
      try {
        final res = await _supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'payment_methods')
            .maybeSingle();
        if (res == null) return fallback;
        final raw = res['value'];
        if (raw is List) {
          final list = raw.map((e) => e.toString()).toList();
          return list.isEmpty ? fallback : list;
        }
        if (raw is String) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final list = decoded.map((e) => e.toString()).toList();
            return list.isEmpty ? fallback : list;
          }
        }
      } catch (_) {}
      return fallback;
    });

final withdrawActionsProvider = Provider((ref) => WithdrawActions(ref));

class WithdrawActions {
  final Ref ref;
  WithdrawActions(this.ref);

  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String targetType,
    String? targetUserId,
    required String paymentMethodId,
  }) async {
    final res = await _supabase.rpc(
      'request_cash_withdrawal',
      params: {
        'p_amount': amount,
        'p_target_type': targetType,
        'p_target_user_id': targetUserId,
        'p_payment_method_id': paymentMethodId,
      },
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(userProfileProvider);
      ref.invalidate(billRecordsProvider);
    }
    return map;
  }

  Future<Map<String, dynamic>> cancelWithdrawal(String id) async {
    final res = await _supabase.rpc(
      'cancel_cash_withdrawal',
      params: {'p_withdrawal_id': id},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(userProfileProvider);
      ref.invalidate(billRecordsProvider);
    }
    return map;
  }

  Future<UserPaymentMethod?> addPaymentMethod({
    required String method,
    required String name,
    required String address,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final res = await _supabase
        .from('user_payment_methods')
        .insert({
          'user_id': user.id,
          'method': method,
          'name': name,
          'address': address,
        })
        .select()
        .single();

    ref.invalidate(userPaymentMethodsProvider);
    return UserPaymentMethod.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> deletePaymentMethod(String id) async {
    await _supabase.from('user_payment_methods').delete().eq('id', id);
    ref.invalidate(userPaymentMethodsProvider);
  }
}

final billRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTime>((ref, day) async {
      final user = ref.watch(authStateProvider).value?.session?.user;
      if (user == null) return [];

      final start = DateTime(day.year, day.month, day.day).toUtc();
      final end = start.add(const Duration(days: 1));

      final res = await _supabase
          .from('wallet_withdrawals')
          .select('*, target:target_user_id(username, short_id, avatar_url)')
          .eq('user_id', user.id)
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res as List);
    });
