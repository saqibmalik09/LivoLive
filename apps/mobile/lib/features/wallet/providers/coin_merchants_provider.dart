import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class CoinMerchant {
  final String id;
  final String username;
  final int? shortId;
  final String? avatarUrl;
  final String? countryCode;
  final DateTime? registrationDate;
  final bool isOnline;

  const CoinMerchant({
    required this.id,
    required this.username,
    this.shortId,
    this.avatarUrl,
    this.countryCode,
    this.registrationDate,
    this.isOnline = false,
  });

  factory CoinMerchant.fromMap(Map<String, dynamic> map) {
    DateTime? reg;
    final raw = map['registration_date'];
    if (raw != null) {
      reg = DateTime.tryParse(raw.toString());
    }
    return CoinMerchant(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? 'Merchant',
      shortId: (map['short_id'] as num?)?.toInt(),
      avatarUrl: map['avatar_url']?.toString(),
      countryCode: map['country_code']?.toString(),
      registrationDate: reg,
      isOnline: map['is_online'] == true,
    );
  }
}

final coinMerchantsProvider = FutureProvider.autoDispose<List<CoinMerchant>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value?.session?.user;
  if (user == null) return [];

  final res = await _supabase.rpc('get_coin_merchants');
  final map = Map<String, dynamic>.from(res as Map);
  if (map['success'] != true) return [];
  final merchants = map['merchants'];
  if (merchants is! List) return [];
  return merchants
      .map((e) => CoinMerchant.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});
