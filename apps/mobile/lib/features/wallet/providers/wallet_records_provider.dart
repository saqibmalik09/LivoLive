import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

enum WalletRecordCurrency { coins, diamonds, balance }

extension WalletRecordCurrencyX on WalletRecordCurrency {
  String get rpcParam {
    switch (this) {
      case WalletRecordCurrency.coins:
        return 'coin';
      case WalletRecordCurrency.diamonds:
        return 'diamond';
      case WalletRecordCurrency.balance:
        return 'cash';
    }
  }

  String get label {
    switch (this) {
      case WalletRecordCurrency.coins:
        return 'Coins';
      case WalletRecordCurrency.diamonds:
        return 'Diamonds';
      case WalletRecordCurrency.balance:
        return 'Balance';
    }
  }
}

class WalletRecord {
  final String id;
  final num amount;
  final String transactionType;
  final String currencyType;
  final String? description;
  final DateTime createdAt;
  final bool isCredit;
  final String title;
  final String subtitle;

  const WalletRecord({
    required this.id,
    required this.amount,
    required this.transactionType,
    required this.currencyType,
    required this.description,
    required this.createdAt,
    required this.isCredit,
    required this.title,
    required this.subtitle,
  });

  factory WalletRecord.fromMap(Map<String, dynamic> map) {
    return WalletRecord(
      id: map['id']?.toString() ?? '',
      amount: map['amount'] as num? ?? 0,
      transactionType: map['transaction_type']?.toString() ?? '',
      currencyType: map['currency_type']?.toString() ?? '',
      description: map['description']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isCredit: map['is_credit'] == true,
      title:
          map['title']?.toString() ??
          map['transaction_type']?.toString() ??
          'Record',
      subtitle: map['subtitle']?.toString() ?? '',
    );
  }
}

final walletRecordsProvider = FutureProvider.autoDispose
    .family<List<WalletRecord>, WalletRecordCurrency>((ref, currency) async {
      final user = ref.watch(authStateProvider).value?.session?.user;
      if (user == null) return [];

      final res = await _supabase.rpc(
        'get_wallet_records',
        params: {
          'p_currency': currency.rpcParam,
          'p_limit': 100,
          'p_offset': 0,
        },
      );

      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return [];
      final records = map['records'];
      if (records is! List) return [];
      return records
          .map((e) => WalletRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
