import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'package:sk_live/core/widgets/stretch_chat_bubble.dart';

final supabase = Supabase.instance.client;

class UserAsset {
  final String id;
  final String itemId;
  final String name;
  final String? imageUrl;
  final String? svgaUrl;
  final String category;
  final int price;
  final bool isEquipped;
  final DateTime expiresAt;

  UserAsset({
    required this.id,
    required this.itemId,
    required this.name,
    this.imageUrl,
    this.svgaUrl,
    required this.category,
    required this.price,
    required this.isEquipped,
    required this.expiresAt,
  });

  factory UserAsset.fromJson(Map<String, dynamic> json) {
    return UserAsset(
      id: json['id'] ?? '',
      itemId: json['item_id'] ?? '',
      name: json['shop_items']?['name'] ?? 'Unknown',
      imageUrl: json['shop_items']?['image_url'],
      svgaUrl: json['shop_items']?['svga_url'],
      category: json['shop_items']?['shop_categories']?['name'] ?? 'Unknown',
      price: json['shop_items']?['price_coins'] ?? 0,
      isEquipped: json['is_equipped'] ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : DateTime.now().add(const Duration(days: 365)),
    );
  }
}

final userAssetsProvider = FutureProvider.autoDispose
    .family<List<UserAsset>, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      try {
        final response = await supabase
            .from('user_inventory')
            .select('*, shop_items(*, shop_categories(*))')
            .eq('user_id', userId)
            .or(
              'expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}',
            );

        final List<UserAsset> items = (response as List)
            .map((e) => UserAsset.fromJson(e))
            .toList();

        final coupleRes = await supabase
            .from('couples')
            .select('cp_level')
            .or('user1_id.eq.$userId,user2_id.eq.$userId')
            .maybeSingle();

        if (coupleRes != null) {
          final cpLevel = (coupleRes['cp_level'] as num?)?.toInt() ?? 0;
          if (cpLevel > 0) {
            final cpConfig = await supabase
                .from('cp_level_configs')
                .select('badge_url, frame_url')
                .eq('level', cpLevel)
                .maybeSingle();

            if (cpConfig != null) {
              if (cpConfig['badge_url'] != null) {
                items.insert(
                  0,
                  UserAsset(
                    id: 'cp_badge_$cpLevel',
                    itemId: 'cp_badge_item_$cpLevel',
                    name: 'CP Lv.$cpLevel Badge',
                    imageUrl: cpConfig['badge_url'],
                    category: 'Medal',
                    price: 1000000,
                    isEquipped: true,
                    expiresAt: DateTime.now().add(const Duration(days: 365)),
                  ),
                );
              }
              if (cpConfig['frame_url'] != null) {
                items.insert(
                  0,
                  UserAsset(
                    id: 'cp_frame_$cpLevel',
                    itemId: 'cp_frame_item_$cpLevel',
                    name: 'CP Lv.$cpLevel Frame',
                    imageUrl: cpConfig['frame_url'],
                    category: 'Profile photo frame',
                    price: 1000000,
                    isEquipped: true,
                    expiresAt: DateTime.now().add(const Duration(days: 365)),
                  ),
                );
              }
            }
          }
        }

        return items;
      } catch (e) {
        return [];
      }
    });

final equippedAssetProvider =
    FutureProvider.family<UserAsset?, ({String userId, String category})>((
      ref,
      arg,
    ) async {
      final assetsAsync = await ref.watch(
        userAssetsProvider(arg.userId).future,
      );

      final categoryAssets = assetsAsync
          .where((a) => a.category.toLowerCase() == arg.category.toLowerCase())
          .toList();
      if (categoryAssets.isEmpty) return null;

      final equipped = categoryAssets.where((a) => a.isEquipped).toList();
      if (equipped.isNotEmpty) return equipped.first;

      categoryAssets.sort((a, b) => b.price.compareTo(a.price));
      return categoryAssets.first;
    });

final equippedBubbleProvider = FutureProvider.autoDispose
    .family<UserAsset?, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      if (userId.isEmpty) return null;
      final assets = await ref.watch(userAssetsProvider(userId).future);
      bool isBubble(UserAsset a) {
        final cat = a.category.toLowerCase();
        final name = a.name.toLowerCase();
        if (cat.contains('bubble') ||
            name.contains('bubble') ||
            name.contains('气泡') ||
            name.contains('buble')) {
          return true;
        }
        return isNineSliceChatBubble(name: a.name, imageUrl: a.imageUrl);
      }

      final bubbles = assets.where(isBubble).toList();
      if (bubbles.isEmpty) return null;
      final equipped = bubbles.where((a) => a.isEquipped).toList();
      final pool = equipped.isNotEmpty ? equipped : bubbles;
      pool.sort((a, b) {
        final aNine = isNineSliceChatBubble(name: a.name, imageUrl: a.imageUrl)
            ? 1
            : 0;
        final bNine = isNineSliceChatBubble(name: b.name, imageUrl: b.imageUrl)
            ? 1
            : 0;
        if (aNine != bNine) return bNine - aNine;
        return b.price.compareTo(a.price);
      });
      return pool.first;
    });

class InventoryActions {
  static Future<void> equipAsset(String assetId, String category) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase.rpc(
        'equip_user_asset',
        params: {
          'p_asset_id': assetId,
          'p_user_id': userId,
          'p_category_name': category,
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}

Future<({String? carSvga, String? pattiUrl, String? pattiSvga})>
fetchUserBestEntranceAssets(String userId) async {
  final supabase = Supabase.instance.client;

  final userRes = await supabase
      .from('users')
      .select('vip_level')
      .eq('id', userId)
      .maybeSingle();
  final vipLevel = (userRes?['vip_level'] as num?)?.toInt() ?? 0;

  bool canShowEntrance = true;
  bool canShowVehicle = true;

  if (vipLevel > 0) {
    final planRes = await supabase
        .from('vip_plans')
        .select('has_entrance_show, has_rare_vehicle')
        .eq('level', vipLevel)
        .maybeSingle();
    if (planRes != null) {
      canShowEntrance = planRes['has_entrance_show'] ?? false;
      canShowVehicle = planRes['has_rare_vehicle'] ?? false;
    }
  }

  final res = await supabase
      .from('user_inventory')
      .select('*, shop_items(*, shop_categories(name))')
      .eq('user_id', userId)
      .or(
        'expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}',
      )
      .order('created_at', ascending: false);

  final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(res);

  String? carSvga;
  final cars = items.where((i) {
    final cat =
        i['shop_items']?['shop_categories']?['name']
            ?.toString()
            .toLowerCase() ??
        '';
    return cat == 'car';
  }).toList();

  if (cars.isNotEmpty) {
    final bestCar = cars.firstWhere(
      (i) => i['is_equipped'] == true,
      orElse: () => cars.first,
    );
    carSvga = MediaUrlUtil.nullableMediaUrl(
      bestCar['shop_items']?['svga_url'] as String?,
    );
  }

  String? pattiUrl;
  String? pattiSvga;
  final entrances = items.where((i) {
    final cat =
        i['shop_items']?['shop_categories']?['name']
            ?.toString()
            .toLowerCase() ??
        '';
    return cat == 'entrance show';
  }).toList();

  if (entrances.isNotEmpty) {
    final bestEntrance = entrances.firstWhere(
      (i) => i['is_equipped'] == true,
      orElse: () => entrances.first,
    );
    final rawImage = MediaUrlUtil.nullableMediaUrl(
      bestEntrance['shop_items']?['image_url'] as String?,
    );
    final rawSvga = MediaUrlUtil.nullableMediaUrl(
      bestEntrance['shop_items']?['svga_url'] as String?,
    );
    final resolved = MediaUrlUtil.resolveEntrancePatti(
      imageUrl: rawImage,
      svgaUrl: rawSvga,
    );
    pattiUrl = resolved.imageUrl;
    pattiSvga = resolved.svgaUrl;
  }

  if ((canShowVehicle && carSvga == null) ||
      (canShowEntrance && (pattiUrl == null && pattiSvga == null))) {
    if (vipLevel > 0) {
      final vipAssets = await supabase
          .from('shop_items')
          .select(
            'image_url, svga_url, name, required_vip_level, shop_categories(name)',
          )
          .eq('is_active', true)
          .or('source_type.eq.vip,name.ilike.VIP%');

      for (var asset in (vipAssets as List)) {
        final catName =
            asset['shop_categories']?['name']?.toString().toLowerCase() ?? '';
        int itemLevel = (asset['required_vip_level'] as num?)?.toInt() ?? 0;

        if (itemLevel == 0) {
          final match = RegExp(
            r'VIP\s*(\d+)',
          ).firstMatch(asset['name']?.toString() ?? '');
          if (match != null) itemLevel = int.parse(match.group(1)!);
        }

        if (itemLevel == vipLevel) {
          if (canShowVehicle && carSvga == null && catName == 'car') {
            carSvga = MediaUrlUtil.nullableMediaUrl(
              asset['svga_url'] as String?,
            );
          }
          if (canShowEntrance &&
              (pattiUrl == null && pattiSvga == null) &&
              catName == 'entrance show') {
            final resolved = MediaUrlUtil.resolveEntrancePatti(
              imageUrl: asset['image_url'] as String?,
              svgaUrl: asset['svga_url'] as String?,
            );
            pattiUrl = resolved.imageUrl;
            pattiSvga = resolved.svgaUrl;
          }
        }
      }
    }
  }

  return (carSvga: carSvga, pattiUrl: pattiUrl, pattiSvga: pattiSvga);
}

final userBestEntranceProvider =
    FutureProvider.family<
      ({String? carSvga, String? pattiUrl, String? pattiSvga}),
      String
    >((ref, userId) async {
      final cached = HiveCacheService.loadEquippedEntrance(userId);
      if (cached != null) {
        Future(() async {
          try {
            final before = HiveCacheService.loadEquipped(
              userId,
            )?['fingerprint'];
            final remote = await fetchUserBestEntranceAssets(userId);
            await HiveCacheService.patchEquippedEntrance(
              userId,
              carSvga: remote.carSvga,
              pattiUrl: remote.pattiUrl,
              pattiSvga: remote.pattiSvga,
            );
            final after = HiveCacheService.loadEquipped(userId)?['fingerprint'];
            if (before != after) {
              ref.invalidateSelf();
            }
          } catch (e) {
            debugPrint('[userBestEntranceProvider] bg refresh failed: $e');
          }
        });
        return cached;
      }

      final remote = await fetchUserBestEntranceAssets(userId);
      await HiveCacheService.patchEquippedEntrance(
        userId,
        carSvga: remote.carSvga,
        pattiUrl: remote.pattiUrl,
        pattiSvga: remote.pattiSvga,
      );
      return remote;
    });

Future<List<Map<String, dynamic>>> fetchUserFullInventory(String userId) async {
  final client = Supabase.instance.client;

  final res = await client
      .from('user_inventory')
      .select('*, shop_items(*, shop_categories(name))')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(res);

  try {
    final coupleRes = await client
        .from('couples')
        .select('cp_level')
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .maybeSingle();

    if (coupleRes != null) {
      final cpLevel = (coupleRes['cp_level'] as num?)?.toInt() ?? 0;
      if (cpLevel > 0) {
        final cpConfig = await client
            .from('cp_level_configs')
            .select('badge_url, frame_url')
            .eq('level', cpLevel)
            .maybeSingle();

        if (cpConfig != null) {
          if (cpConfig['badge_url'] != null) {
            items.insert(0, {
              'id': 'cp_badge_$cpLevel',
              'user_id': userId,
              'item_id': 'cp_badge_item_$cpLevel',
              'is_equipped': true,
              'shop_items': {
                'id': 'cp_badge_item_$cpLevel',
                'name': 'CP Lv.$cpLevel Badge',
                'image_url': cpConfig['badge_url'],
                'source_type': 'medal',
                'shop_categories': {'name': 'Medal'},
              },
            });
          }
          if (cpConfig['frame_url'] != null) {
            items.insert(0, {
              'id': 'cp_frame_$cpLevel',
              'user_id': userId,
              'item_id': 'cp_frame_item_$cpLevel',
              'is_equipped': true,
              'shop_items': {
                'id': 'cp_frame_item_$cpLevel',
                'name': 'CP Lv.$cpLevel Frame',
                'image_url': cpConfig['frame_url'],
                'shop_categories': {'name': 'Frame'},
              },
            });
          }
        }
      }
    }
  } catch (_) {}

  return items;
}

final userFullInventoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      final cached = HiveCacheService.loadBackpack(userId);
      if (cached != null) {
        Future(() async {
          try {
            final remote = await fetchUserFullInventory(userId);
            final changed = await HiveCacheService.saveBackpack(userId, remote);
            if (changed) {
              ref.invalidateSelf();
            }
          } catch (e) {
            debugPrint('[userFullInventoryProvider] bg refresh failed: $e');
          }
        });
        return cached;
      }

      try {
        final remote = await fetchUserFullInventory(userId);
        await HiveCacheService.saveBackpack(userId, remote);
        return remote;
      } catch (e) {
        debugPrint('[userFullInventoryProvider] fetch failed: $e');
        return [];
      }
    });

void invalidateUserInventoryCaches(
  void Function(ProviderOrFamily provider) invalidate,
  String userId,
) {
  invalidate(userAssetsProvider(userId));
  invalidate(userFullInventoryProvider(userId));
  invalidate(userBestEntranceProvider(userId));
  invalidate(userEquippedFrameProvider(userId));
  invalidate(userBadgesProvider(userId));
  if (supabase.auth.currentUser?.id == userId) {
    invalidate(userProfileProvider);
  }
}

Future<void> refreshUserInventoryCaches(WidgetRef ref, String userId) async {
  invalidateUserInventoryCaches(ref.invalidate, userId);

  final frame = await fetchUserEquippedFrame(userId);
  final entrance = await fetchUserBestEntranceAssets(userId);
  final backpack = await fetchUserFullInventory(userId);
  final badges = await fetchUserBadges(ref.watch, userId);

  await Future.wait([
    HiveCacheService.saveEquipped(userId, {
      'frame':
          frame == null ||
              ((frame['image_url'] == null ||
                      frame['image_url']!.trim().isEmpty) &&
                  (frame['svga_url'] == null ||
                      frame['svga_url']!.trim().isEmpty))
          ? null
          : {'image_url': frame['image_url'], 'svga_url': frame['svga_url']},
      'car': (entrance.carSvga == null || entrance.carSvga!.isEmpty)
          ? null
          : {'svga_url': entrance.carSvga},
      'entrance':
          ((entrance.pattiUrl == null || entrance.pattiUrl!.isEmpty) &&
              (entrance.pattiSvga == null || entrance.pattiSvga!.isEmpty))
          ? null
          : {'patti_url': entrance.pattiUrl, 'patti_svga': entrance.pattiSvga},
    }),
    HiveCacheService.saveBackpack(userId, backpack),
    HiveCacheService.saveBadges(userId, badges.map((b) => b.toJson()).toList()),
  ]);

  final futures = <Future<void>>[
    ref.refresh(userFullInventoryProvider(userId).future).then((_) {}),
    ref.refresh(userEquippedFrameProvider(userId).future).then((_) {}),
    ref.refresh(userBestEntranceProvider(userId).future).then((_) {}),
    ref.refresh(userBadgesProvider(userId).future).then((_) {}),
  ];
  if (supabase.auth.currentUser?.id == userId) {
    futures.add(ref.refresh(userProfileProvider.future).then((_) {}));
  }
  await Future.wait(futures);
}
