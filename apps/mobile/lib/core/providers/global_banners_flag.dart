import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String kGlobalBannersEnabledKey = 'global_banners_enabled';

bool parseGlobalBannersEnabled(Object? raw) {
  final v = raw?.toString().trim().toLowerCase();
  return !(v == 'false' || v == '0' || v == 'off' || v == 'no');
}

typedef GlobalBannersFetch = Future<bool?> Function();

Future<bool?> fetchGlobalBannersEnabled() async {
  try {
    final rows = await Supabase.instance.client
        .from('system_settings')
        .select('value')
        .eq('key', kGlobalBannersEnabledKey)
        .limit(1);
    if (rows.isEmpty) return true;
    return parseGlobalBannersEnabled(rows.first['value']);
  } catch (_) {
    return null;
  }
}

final globalBannersFetchProvider = Provider<GlobalBannersFetch>(
  (ref) => fetchGlobalBannersEnabled,
);

final globalBannersEnabledProvider = StateProvider<bool>((ref) => true);
