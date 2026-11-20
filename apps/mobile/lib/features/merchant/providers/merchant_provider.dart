import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Merchant tier — the wholesale layer above coin sellers.
///
/// Every call is scoped to the signed-in merchant by the RPC itself
/// (`auth.uid()`), so no user id is passed from the client.

List<Map<String, dynamic>> _rows(dynamic res) {
  if (res is List) {
    return res
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
  return const [];
}

/// Wallet balance, total sales, total profit, deposits, seller count.
final merchantOverviewProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;
      final res = await Supabase.instance.client.rpc('get_merchant_overview');
      if (res is Map) return Map<String, dynamic>.from(res);
      return null;
    });

/// Full movement history. [filter] is null (everything), `deposits`,
/// `sales` or `withdrawals` — matching get_merchant_ledger's p_type.
final merchantLedgerProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, filter) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return const [];
      final res = await Supabase.instance.client.rpc(
        'get_merchant_ledger',
        params: {'p_type': filter, 'p_limit': 100},
      );
      return _rows(res);
    });

/// Coin sellers this merchant supplies.
final merchantResellersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return const [];
      final res = await Supabase.instance.client.rpc('get_merchant_resellers');
      return _rows(res);
    });

/// This merchant's withdrawal requests.
final merchantWithdrawalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return const [];
      final res = await Supabase.instance.client.rpc(
        'get_merchant_withdrawals',
      );
      return _rows(res);
    });

/// Coin-seller lookup by numeric ID or name — requirement 4's ID search.
final merchantSellerSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
      final q = query.trim();
      if (q.isEmpty) return const [];
      // Numeric IDs are exact, so one digit is enough; names need two
      // characters before we start querying on every keystroke.
      final isNumeric = RegExp(r'^\d+$').hasMatch(q);
      if (!isNumeric && q.length < 2) return const [];
      final res = await Supabase.instance.client.rpc(
        'merchant_search_coin_sellers',
        params: {'p_query': q, 'p_limit': 20},
      );
      return _rows(res);
    });

/// Account lookup for topping up a normal user's ID — any account, not just
/// coin sellers. Mirrors merchant_search_coin_sellers but unrestricted.
final merchantUserSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
      final q = query.trim();
      if (q.isEmpty) return const [];
      final isNumeric = RegExp(r'^\d+$').hasMatch(q);
      if (!isNumeric && q.length < 2) return const [];
      final res = await Supabase.instance.client.rpc(
        'merchant_search_users',
        params: {'p_query': q, 'p_limit': 20},
      );
      return _rows(res);
    });

/// Refresh everything after a transfer or withdrawal.
void invalidateMerchantData(WidgetRef ref) {
  ref.invalidate(merchantOverviewProvider);
  ref.invalidate(merchantLedgerProvider);
  ref.invalidate(merchantResellersProvider);
  ref.invalidate(merchantWithdrawalsProvider);
}
