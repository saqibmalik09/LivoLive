import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/dev_log.dart';

const int kHomeTopBannerHeightMin = 80;
const int kHomeTopBannerHeightMax = 400;
const int kHomeTopBannerHeightDefault = 160;

int clampHomeTopBannerHeight(num? raw) {
  final n = raw?.round() ?? kHomeTopBannerHeightDefault;
  if (!n.isFinite) return kHomeTopBannerHeightDefault;
  return n.clamp(kHomeTopBannerHeightMin, kHomeTopBannerHeightMax);
}

final homeTopBannerHeightProvider = FutureProvider<int>((ref) async {
  ref.keepAlive();
  try {
    final row = await Supabase.instance.client
        .from('system_settings')
        .select('value')
        .eq('key', 'home_top_banner_height')
        .maybeSingle();
    return clampHomeTopBannerHeight(
      num.tryParse(row?['value']?.toString() ?? ''),
    );
  } catch (e) {
    debugPrint('[homeTopBannerHeightProvider] $e');
    return kHomeTopBannerHeightDefault;
  }
});

final bannersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      placement,
    ) async {
      ref.keepAlive();

      final cached = HiveCacheService.loadBanners(placement: placement);

      Future<List<Map<String, dynamic>>> fetchRemote() async {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('banners')
            .select()
            .eq('is_active', true)
            .eq('placement', placement)
            .order('priority', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      }

      if (cached != null && cached.isNotEmpty) {
        Future(() async {
          try {
            final remote = await fetchRemote();
            final changed = await HiveCacheService.saveBanners(
              remote,
              placement: placement,
            );
            if (changed) {
              ref.invalidateSelf();
            }
          } catch (e) {
            debugPrint('[bannersProvider] bg refresh failed: $e');
          }
        });
        return cached;
      }

      try {
        final remote = await fetchRemote();
        await HiveCacheService.saveBanners(remote, placement: placement);
        return remote;
      } catch (e) {
        debugPrint('[bannersProvider] fetch failed: $e');
        return cached ?? [];
      }
    });

final topBannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(bannersProvider('top').future);
});

final afterRoomsBannersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(bannersProvider('after_rooms').future);
});

final profileBannersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return ref.watch(bannersProvider('profile').future);
});

final cpRankingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('cp_rankings')
      .select(
        '*, user_1:user_1_id(username, avatar_url), user_2:user_2_id(username, avatar_url)',
      )
      .order('rank', ascending: true)
      .limit(1);
  return List<Map<String, dynamic>>.from(response);
});

final familyRankingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('family_rankings')
      .select()
      .order('rank', ascending: true)
      .limit(1);
  return List<Map<String, dynamic>>.from(response);
});

final roomRankingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('room_rankings')
      .select('*, room:room_id(title, image_url)')
      .order('rank', ascending: true)
      .limit(1);
  return List<Map<String, dynamic>>.from(response);
});

final charmRankingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('charm_rankings')
      .select('*, user:user_id(username, avatar_url)')
      .order('rank', ascending: true)
      .limit(1);
  return List<Map<String, dynamic>>.from(response);
});

final giftRankingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('gift_rankings')
      .select('*, user:user_id(username, avatar_url)')
      .order('rank', ascending: true)
      .limit(1);
  return List<Map<String, dynamic>>.from(response);
});

final activeRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  try {
    devLog('DEBUG: Fetching active rooms from view...');
    final response = await supabase
        .from('active_rooms_with_rankings')
        .select('*')
        .order('created_at', ascending: false)
        .limit(30);

    devLog('DEBUG: Successfully fetched ${response.length} active rooms');

    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final room in response) {
      final id = room['id']?.toString();
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      unique.add(Map<String, dynamic>.from(room));
    }
    if (unique.length != response.length) {
      devLog(
        'DEBUG: Deduped active rooms ${response.length} -> ${unique.length}',
      );
    }
    return unique;
  } catch (e, stack) {
    devLog('DEBUG ERROR in activeRoomsProvider: $e');
    devLog('DEBUG STACKTRACE: $stack');
    rethrow;
  }
});

final selectedCountryProvider = StateProvider<String>((ref) => '');

final roomsByCountryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final countryCode = ref.watch(selectedCountryProvider);
  if (countryCode.isEmpty) return [];

  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('active_rooms_with_rankings')
      .select(
        '*, host:host_id!inner(username, avatar_url, country_code, short_id)',
      )
      .eq('host.country_code', countryCode)
      .order('created_at', ascending: false);

  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final room in response) {
    final id = room['id']?.toString();
    if (id == null || seen.contains(id)) continue;
    seen.add(id);
    unique.add(Map<String, dynamic>.from(room));
  }
  return unique;
});
final managedRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final response = await supabase
      .from('room_members')
      .select('room:room_id(*)')
      .eq('user_id', user.id)
      .eq('role', 'admin');

  return (response as List)
      .map((m) => Map<String, dynamic>.from(m['room']))
      .toList();
});

final followedRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final response = await supabase
      .from('room_members')
      .select('room:room_id(*)')
      .eq('user_id', user.id)
      .eq('role', 'member');

  return (response as List)
      .map((m) => Map<String, dynamic>.from(m['room']))
      .toList();
});
