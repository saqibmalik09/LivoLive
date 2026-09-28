import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/task_tracker_service.dart';

final supabase = Supabase.instance.client;

class RechargePackage {
  final String id;
  final int coinsAmount;
  final double priceUsd;
  final String? playStoreId;

  RechargePackage({
    required this.id,
    required this.coinsAmount,
    required this.priceUsd,
    this.playStoreId,
  });

  factory RechargePackage.fromMap(Map<String, dynamic> map) {
    return RechargePackage(
      id: map['id'],
      coinsAmount: map['beans_amount'],
      priceUsd: (map['price_usd'] as num).toDouble(),
      playStoreId: map['play_store_id'],
    );
  }
}

class ExchangeConfig {
  final String id;
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final int minAmount;

  ExchangeConfig({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.minAmount,
  });

  factory ExchangeConfig.fromMap(Map<String, dynamic> map) {
    return ExchangeConfig(
      id: map['id'],
      fromCurrency: map['from_currency'] == 'beans'
          ? 'coins'
          : map['from_currency'],
      toCurrency: map['to_currency'] == 'beans' ? 'coins' : map['to_currency'],
      rate: (map['rate'] as num).toDouble(),
      minAmount: map['min_amount'],
    );
  }
}

final rechargePackagesProvider = FutureProvider<List<RechargePackage>>((
  ref,
) async {
  final res = await supabase
      .from('recharge_packages')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  return (res as List).map((e) => RechargePackage.fromMap(e)).toList();
});

final exchangeConfigsProvider = FutureProvider<List<ExchangeConfig>>((
  ref,
) async {
  final res = await supabase
      .from('exchange_configs')
      .select()
      .eq('is_active', true);

  return (res as List).map((e) => ExchangeConfig.fromMap(e)).toList();
});

class CashExchangeConfig {
  final String id;
  final int coinsPerDollar;
  final double bonusPercent;

  const CashExchangeConfig({
    required this.id,
    required this.coinsPerDollar,
    required this.bonusPercent,
  });

  factory CashExchangeConfig.fromMap(Map<String, dynamic> map) {
    return CashExchangeConfig(
      id: map['id'] as String,
      coinsPerDollar: (map['coins_per_dollar'] as num?)?.toInt() ?? 68000,
      bonusPercent: (map['bonus_percent'] as num?)?.toDouble() ?? 0,
    );
  }

  int coinsForUsd(num usd) {
    final base = (usd * coinsPerDollar).floor();
    final bonus = (base * bonusPercent / 100).floor();
    return base + bonus;
  }

  int baseCoinsForUsd(num usd) => (usd * coinsPerDollar).floor();

  int bonusCoinsForUsd(num usd) {
    final base = baseCoinsForUsd(usd);
    return (base * bonusPercent / 100).floor();
  }
}

final cashExchangeConfigProvider = FutureProvider<CashExchangeConfig?>((
  ref,
) async {
  final res = await supabase
      .from('cash_exchange_configs')
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (res == null) return null;
  return CashExchangeConfig.fromMap(Map<String, dynamic>.from(res));
});

class DiamondSalaryConfig {
  final String id;
  final int diamondsUnit;
  final double usdPerUnit;

  const DiamondSalaryConfig({
    required this.id,
    required this.diamondsUnit,
    required this.usdPerUnit,
  });

  factory DiamondSalaryConfig.fromMap(Map<String, dynamic> map) {
    return DiamondSalaryConfig(
      id: map['id'] as String,
      diamondsUnit: (map['diamonds_unit'] as num?)?.toInt() ?? 150000,
      usdPerUnit: (map['usd_per_unit'] as num?)?.toDouble() ?? 0.75,
    );
  }

  double usdForDiamonds(int diamonds) {
    if (diamondsUnit <= 0) return 0;
    final units = diamonds ~/ diamondsUnit;
    return units * usdPerUnit;
  }

  int maxExchangeable(int diamonds) {
    if (diamondsUnit <= 0) return 0;
    return (diamonds ~/ diamondsUnit) * diamondsUnit;
  }
}

final diamondSalaryConfigProvider = FutureProvider<DiamondSalaryConfig?>((
  ref,
) async {
  final res = await supabase
      .from('diamond_salary_configs')
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (res == null) return null;
  return DiamondSalaryConfig.fromMap(Map<String, dynamic>.from(res));
});

final walletActionsProvider = Provider((ref) => WalletActions(ref));

class WalletActions {
  final Ref ref;
  WalletActions(this.ref);

  Future<bool> performExchange({
    required String fromCurrency,
    required String toCurrency,
    required int amount,
  }) async {
    try {
      final res = await supabase.rpc(
        'exchange_wallet_currency',
        params: {
          'p_from_currency': fromCurrency,
          'p_to_currency': toCurrency,
          'p_amount': amount,
        },
      );
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) {
        throw map['message']?.toString() ?? 'Exchange failed';
      }
      ref.invalidate(userProfileProvider);
      return true;
    } catch (e) {
      debugPrint('Exchange Error: $e');
      final msg = e.toString();
      if (msg.contains('row-level security') || msg.contains('42501')) {
        throw 'Exchange failed. Pull to refresh and try again. If it keeps failing, update the app.';
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> exchangeCashToSelf(num amountUsd) async {
    final res = await supabase.rpc(
      'exchange_cash_to_self',
      params: {'p_amount_usd': amountUsd},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(userProfileProvider);
    }
    return map;
  }

  Future<Map<String, dynamic>> exchangeCashToOther({
    required String targetUserId,
    required num amountUsd,
  }) async {
    final res = await supabase.rpc(
      'exchange_cash_to_other',
      params: {'p_target_user_id': targetUserId, 'p_amount_usd': amountUsd},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(userProfileProvider);
    }
    return map;
  }

  Future<Map<String, dynamic>> exchangeDiamondsToSalary(int diamonds) async {
    final res = await supabase.rpc(
      'exchange_diamonds_to_salary',
      params: {'p_diamonds': diamonds},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(userProfileProvider);
    }
    return map;
  }

  Future<bool> addCoins(int amount, String reference) async {
    debugPrint(
      'addCoins deprecated; use deliverIapPurchase ($amount, $reference)',
    );
    return false;
  }

  Future<Map<String, dynamic>> deliverIapPurchase({
    required String productId,
    required String purchaseId,
    String? purchaseToken,
  }) async {
    try {
      final token = purchaseToken?.trim() ?? '';
      if (token.length < 20) {
        return {'success': false, 'message': 'Missing Play purchase token'};
      }

      final res = await supabase.functions.invoke(
        'verify-and-deliver-iap',
        body: {
          'productId': productId,
          'purchaseId': purchaseId,
          'purchaseToken': token,
        },
      );

      final map = _iapResponseMap(res.data);
      if (map['success'] == true) {
        final coins = (map['coins'] as num?)?.toInt() ?? 0;
        final dup = map['duplicate'] == true;
        if (!dup && coins > 0) {
          await TaskTrackerService.trackAction('recharge_once', amount: 1);
          await TaskTrackerService.trackAction(
            'recharge_accumulated',
            amount: coins,
          );
        }
        ref.invalidate(userProfileProvider);
      } else if (map['message'] == null && res.status >= 400) {
        map['message'] = 'IAP verify failed (${res.status})';
      }
      return map;
    } on FunctionException catch (e) {
      debugPrint('IAP FunctionException: ${e.status} ${e.details}');
      final map = _iapResponseMap(e.details);
      if (map['message'] == null) {
        map['success'] = false;
        map['message'] = e.reasonPhrase ?? 'IAP verify failed (${e.status})';
      }
      return map;
    } catch (e) {
      debugPrint('IAP deliver error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Map<String, dynamic> _iapResponseMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = raw;
        return {'success': false, 'message': decoded};
      } catch (_) {}
    }
    return {'success': false, 'message': 'Unexpected IAP response'};
  }
}
