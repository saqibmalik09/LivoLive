import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'auth_provider.dart';
import 'inventory_provider.dart';

final supabase = Supabase.instance.client;

class VipPlan {
  final String id;
  final int level;
  final String name;
  final int priceCoins;
  final int durationDays;
  final String? imageUrl;
  final String? lottieUrl;
  final Map<String, bool> features;

  VipPlan({
    required this.id,
    required this.level,
    required this.name,
    required this.priceCoins,
    this.durationDays = 30,
    this.imageUrl,
    this.lottieUrl,
    required this.features,
  });

  factory VipPlan.fromMap(Map<String, dynamic> map) {
    final features = <String, bool>{};
    map.forEach((key, value) {
      if (key.startsWith('has_') && value is bool) {
        features[key] = value;
      }
    });

    return VipPlan(
      id: map['id'],
      level: map['level'],
      name: map['name'],
      priceCoins: map['price_coins'],
      durationDays: map['duration_days'] ?? 30,
      imageUrl: map['image_url'],
      lottieUrl: map['lottie_url'],
      features: features,
    );
  }
}

class VipFeatureDetail {
  final String key;
  final String name;
  final String description;
  final String category;
  final String? imageUrl;
  final String? lottieUrl;

  VipFeatureDetail({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    this.imageUrl,
    this.lottieUrl,
  });

  factory VipFeatureDetail.fromMap(Map<String, dynamic> map) {
    return VipFeatureDetail(
      key: map['key'],
      name: map['name'],
      description: map['description'],
      category: map['category'],
      imageUrl: map['image_url'],
      lottieUrl: map['lottie_url'],
    );
  }
}

final vipPlansProvider = FutureProvider<List<VipPlan>>((ref) async {
  final response = await supabase
      .from('vip_plans')
      .select()
      .order('level', ascending: true);

  return (response as List).map((e) => VipPlan.fromMap(e)).toList();
});

final vipFeatureDetailsProvider = FutureProvider<List<VipFeatureDetail>>((
  ref,
) async {
  final response = await supabase.from('vip_feature_details').select();
  return (response as List).map((e) => VipFeatureDetail.fromMap(e)).toList();
});

final vipLevelAssetsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await supabase
      .from('shop_items')
      .select('*, shop_categories(name)')
      .eq('is_active', true)
      .or('source_type.eq.vip,name.ilike.VIP%');

  return (response as List).map((e) {
    final catName =
        e['shop_categories']?['name']?.toString().toLowerCase() ?? '';
    String featureKey = 'unknown';
    if (catName.contains('frame')) featureKey = 'has_exclusive_frame';
    if (catName.contains('entrance')) featureKey = 'has_entrance_show';
    if (catName.contains('profile card background'))
      featureKey = 'has_distinguished_card';
    if (catName.contains('vip titles')) featureKey = 'has_vip_title';
    if (catName.contains('bubble')) featureKey = 'has_chat_bubble';

    int level = (e['required_vip_level'] as num?)?.toInt() ?? 0;
    if (level == 0) {
      final name = e['name']?.toString() ?? '';
      final match = RegExp(r'VIP\s*(\d+)').firstMatch(name);
      if (match != null) {
        level = int.parse(match.group(1)!);
      }
    }

    return {
      'feature_key': featureKey,
      'level': level,
      'image_url': e['image_url'],
      'svga_url': e['svga_url'],
      'name': e['name'],
    };
  }).toList();
});

final userVipProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value(null);

  return realtimeWithFallback<Map<String, dynamic>?>(
    fetch: () async {
      final row = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    },
    realtime: () => supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((event) => event.isEmpty ? null : event.first),
  );
});

final vipPurchaseControllerProvider = Provider(
  (ref) => VipPurchaseController(ref),
);

class VipPurchaseController {
  final Ref ref;
  VipPurchaseController(this.ref);

  Future<bool> purchaseVip(VipPlan plan) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await supabase.rpc(
        'purchase_vip',
        params: {'p_user_id': userId, 'p_plan_id': plan.id},
      );

      if (response['success'] == false) {
        throw response['message'] ?? 'Purchase failed';
      }

      ref.invalidate(userProfileProvider);
      invalidateUserInventoryCaches(ref.invalidate, userId);

      return true;
    } catch (e) {
      debugPrint('VIP Purchase Error: $e');
      rethrow;
    }
  }
}

const forbiddenVipPrivileges = [
  'has_rare_vehicle',
  'has_discount',
  'has_mic_emojis',
  'has_privilege_gift',
  'has_special_gift',
  'has_invisibility',
];

final vipBadgeProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  if (level <= 0) return null;
  try {
    final res = await supabase
        .from('vip_plans')
        .select('image_url')
        .eq('level', level)
        .maybeSingle();

    return res?['image_url'] as String?;
  } catch (e) {
    debugPrint('Error fetching VIP badge: $e');
    return null;
  }
});

final vipFrameProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  if (level <= 0) return null;
  try {
    final res = await supabase
        .from('shop_items')
        .select('image_url, shop_categories(name)')
        .eq('source_type', 'vip')
        .eq('required_vip_level', level)
        .order('id', ascending: true);

    final filtered = (res as List)
        .where(
          (e) => e['shop_categories']['name'].toString().toLowerCase().contains(
            'frame',
          ),
        )
        .toList();

    return filtered.isNotEmpty ? filtered.first['image_url'] as String? : null;
  } catch (e) {
    debugPrint('Error fetching VIP frame: $e');
    return null;
  }
});

final vipCardProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  if (level <= 0) return null;
  try {
    final res = await supabase
        .from('shop_items')
        .select('image_url, shop_categories(name)')
        .eq('source_type', 'vip')
        .eq('required_vip_level', level);

    final filtered = (res as List)
        .where(
          (e) => e['shop_categories']['name'].toString().toLowerCase().contains(
            'profile card background',
          ),
        )
        .toList();

    return filtered.isNotEmpty ? filtered.first['image_url'] as String? : null;
  } catch (e) {
    debugPrint('Error fetching VIP card: $e');
    return null;
  }
});
