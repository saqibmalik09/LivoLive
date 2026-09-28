import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'auth_provider.dart';
import 'level_config_provider.dart';

final supabase = Supabase.instance.client;

final userStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      try {
        final followingCount = await supabase
            .from('follows')
            .count(CountOption.exact)
            .eq('follower_id', userId);

        final followersCount = await supabase
            .from('follows')
            .count(CountOption.exact)
            .eq('following_id', userId);

        final profileRes = await supabase
            .from('users')
            .select('charm_value')
            .eq('id', userId)
            .single();
        final charmValue = profileRes['charm_value'] as int? ?? 0;

        return {
          'following': followingCount,
          'followers': followersCount,
          'charm': charmValue,
          'visits': await _fetchProfileVisitCount(userId),
        };
      } catch (e) {
        return {'following': 0, 'followers': 0, 'charm': 0, 'visits': 0};
      }
    });

Future<int> _fetchProfileVisitCount(String userId) async {
  try {
    final res = await supabase.rpc(
      'get_profile_visit_count',
      params: {'p_profile_id': userId},
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return int.tryParse(res?.toString() ?? '') ?? 0;
  } catch (e) {
    debugPrint('[profile] visit count failed: $e');
    return 0;
  }
}

Future<void> recordProfileVisit(String profileId) async {
  final me = supabase.auth.currentUser?.id;
  if (me == null || me == profileId || profileId.isEmpty) return;
  try {
    await supabase.rpc(
      'record_profile_visit',
      params: {'p_profile_id': profileId},
    );
  } catch (e) {
    debugPrint('[profile] record visit failed: $e');
  }
}

final currentUserStatsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final userProfile = ref.watch(userProfileProvider);
  final userId = userProfile.value?['id'];

  if (userId == null) {
    return {'following': 0, 'followers': 0, 'charm': 0, 'visits': 0};
  }

  return await ref.watch(userStatsProvider(userId).future);
});

final walletProvider = Provider<Map<String, int>>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;

  return {
    'coins': userProfile?['coins'] as int? ?? 0,
    'diamonds': userProfile?['diamonds'] as int? ?? 0,
  };
});

final canAccessDiamondsProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.session?.user.id;
  if (userId == null) return false;

  try {
    final host = await supabase
        .from('agency_members')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    if (host != null) return true;

    final agency = await supabase
        .from('agencies')
        .select('id')
        .eq('owner_id', userId)
        .maybeSingle();
    if (agency != null) return true;

    final staff = await supabase
        .from('business_staff')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();
    return staff != null;
  } catch (e) {
    debugPrint('canAccessDiamondsProvider: $e');
    return false;
  }
});

final wealthBadgeProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  try {
    final response = await supabase
        .from('level_configs')
        .select('badge_url')
        .eq('category', 'user_wealth')
        .eq('level', level)
        .maybeSingle();
    return response?['badge_url'] as String?;
  } catch (e) {
    debugPrint('Error fetching wealth badge: $e');
    return null;
  }
});

final charmBadgeProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  try {
    final configs = await ref.watch(charmLevelConfigsProvider.future);
    for (final config in configs) {
      if ((config['level'] as num?)?.toInt() == level) {
        final fromAssets = badgeUrlForLevelConfig(UserLevelKind.charm, config);
        if (fromAssets != null && fromAssets.isNotEmpty) return fromAssets;
        break;
      }
    }

    final response = await supabase
        .from('charm_level_assets')
        .select('image_url')
        .eq('level', level)
        .eq('feature_key', 'badge')
        .maybeSingle();
    return response?['image_url'] as String?;
  } catch (e) {
    debugPrint('Error fetching charm badge: $e');
    return null;
  }
});

final roomBadgeProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  try {
    final response = await supabase
        .from('level_configs')
        .select('badge_url')
        .eq('category', 'user_wealth')
        .eq('level', level)
        .maybeSingle();
    return response?['badge_url'] as String?;
  } catch (e) {
    debugPrint('Error fetching room badge: $e');
    return null;
  }
});

final cpBadgeProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, score) async {
      cacheFamilyEntry(ref);
      try {
        final response = await supabase
            .from('cp_level_configs')
            .select('level, badge_url')
            .lte('min_exp', score)
            .order('level', ascending: false)
            .limit(1)
            .maybeSingle();
        return response;
      } catch (e) {
        debugPrint('Error fetching CP badge: $e');
        return null;
      }
    });

final familyBadgeProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  try {
    final response = await supabase
        .from('family_level_assets')
        .select('image_url')
        .eq('feature_key', 'badge')
        .lte('level', level)
        .order('level', ascending: false)
        .limit(1);

    if (response.isNotEmpty) {
      return response[0]['image_url'] as String?;
    }

    final fallbackResponse = await supabase
        .from('family_level_assets')
        .select('image_url')
        .eq('feature_key', 'badge')
        .order('level', ascending: true)
        .limit(1);

    if (fallbackResponse.isNotEmpty) {
      return fallbackResponse[0]['image_url'] as String?;
    }

    return null;
  } catch (e) {
    debugPrint('Error fetching family badge: $e');
    return null;
  }
});

final familyFrameProvider = FutureProvider.autoDispose.family<String?, int>((
  ref,
  level,
) async {
  cacheFamilyEntry(ref);
  try {
    final response = await supabase
        .from('family_level_assets')
        .select('image_url')
        .eq('feature_key', 'frame')
        .lte('level', level)
        .order('level', ascending: false)
        .limit(1);

    if ((response as List).isNotEmpty) {
      return response[0]['image_url'] as String?;
    }

    final fallbackResponse = await supabase
        .from('family_level_assets')
        .select('image_url')
        .eq('feature_key', 'frame')
        .order('level', ascending: true)
        .limit(1);

    if ((fallbackResponse as List).isNotEmpty) {
      return fallbackResponse[0]['image_url'] as String?;
    }

    return null;
  } catch (e) {
    debugPrint('Error fetching family frame: $e');
    return null;
  }
});

Future<Map<String, dynamic>?> _fetchProfileVipFrame(int vipLevel) async {
  try {
    final res = await supabase
        .from('shop_items')
        .select('id, name, image_url, svga_url, shop_categories(name)')
        .eq('source_type', 'vip')
        .eq('required_vip_level', vipLevel)
        .eq('is_active', true)
        .limit(5);

    for (final row in res as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final catName =
          map['shop_categories']?['name']?.toString().toLowerCase() ?? '';
      if (catName.contains('frame')) return map;
    }
  } catch (e) {
    debugPrint('Error fetching VIP frame for profile: $e');
  }
  return null;
}

List<Map<String, dynamic>> _mapReceivedGiftsSummary(dynamic giftRows) {
  if (giftRows is! List) return [];
  return giftRows.map((row) {
    final m = Map<String, dynamic>.from(row as Map);
    return {
      'id': m['id'],
      'name': m['name'],
      'image_url': m['image_url'],
      'count': (m['count'] as num?)?.toInt() ?? 0,
    };
  }).toList();
}

final publicUserProfileProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      return AppTelemetry.traceAsync(
        'profile_load',
        () => _loadPublicUserProfile(ref, userId),
        keys: {'user_id': userId},
        slowMs: 3000,
      );
    });

Future<Map<String, dynamic>?> _loadPublicUserProfile(
  Ref ref,
  String userId,
) async {
  try {
    final userRes = await supabase
        .from('users')
        .select('*, family:families(id, name, avatar_url)')
        .eq('id', userId)
        .maybeSingle();

    if (userRes == null) return null;

    final vipLevel = (userRes['vip_level'] as num?)?.toInt() ?? 0;

    final batch = await Future.wait<dynamic>([
      ref.read(userStatsProvider(userId).future),
      supabase.rpc('user_total_sent', params: {'p_user': userId}),
      supabase
          .from('user_inventory')
          .select(
            'si:shop_items(id, name, image_url, svga_url, category_id, sc:shop_categories(name))',
          )
          .eq('user_id', userId)
          .limit(20),
      supabase.rpc(
        'user_received_gifts_summary',
        params: {'p_user': userId, 'p_limit': 10},
      ),
      supabase
          .from('couples')
          .select(
            '*, user1:user1_id(id, username, avatar_url), user2:user2_id(id, username, avatar_url)',
          )
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .maybeSingle(),
      vipLevel > 0
          ? _fetchProfileVipFrame(vipLevel)
          : Future<Map<String, dynamic>?>.value(null),
    ]);

    final stats = batch[0] as Map<String, dynamic>;
    final totalSent = (batch[1] as num?)?.toInt() ?? 0;
    final inventoryRes = batch[2] as List;
    final gifts = _mapReceivedGiftsSummary(batch[3]);
    final coupleRes = batch[4] as Map<String, dynamic>?;
    final vipFrame = batch[5] as Map<String, dynamic>?;

    final List<Map<String, dynamic>> frames = [];
    final List<Map<String, dynamic>> cars = [];

    if (vipFrame != null) {
      frames.add({
        'id': vipFrame['id'],
        'name': vipFrame['name'],
        'image_url': vipFrame['image_url'],
        'svga_url': vipFrame['svga_url'],
        'is_vip': true,
      });
    }

    for (var item in inventoryRes) {
      final si = item['si'] as Map<String, dynamic>?;
      if (si == null) continue;

      final sc = si['sc'] as Map<String, dynamic>?;
      final catName = sc?['name']?.toString().toLowerCase() ?? '';

      if (catName.contains('frame')) {
        frames.add(si);
      } else if (catName.contains('car') ||
          catName.contains('entrance') ||
          catName.contains('ride')) {
        cars.add(si);
      }
    }

    Map<String, dynamic>? cpData;
    if (coupleRes != null) {
      final bool isUser1 = coupleRes['user1_id'] == userId;
      final partner = isUser1 ? coupleRes['user2'] : coupleRes['user1'];
      final int cpLevel = coupleRes['cp_level'] ?? 0;

      String? badgeUrl;
      if (cpLevel > 0) {
        final cpConfig = await supabase
            .from('cp_level_configs')
            .select('badge_url')
            .eq('level', cpLevel)
            .maybeSingle();
        badgeUrl = cpConfig?['badge_url'];
      }

      cpData = {
        'partner': partner,
        'cp_level': cpLevel,
        'cp_exp': coupleRes['cp_exp'],
        'badge_url': badgeUrl,
        'created_at': coupleRes['created_at'],
        'days': () {
          final raw = coupleRes['created_at']?.toString();
          if (raw == null || raw.isEmpty) return 0;
          final started = DateTime.tryParse(raw)?.toLocal();
          if (started == null) return 0;
          final days = DateTime.now().difference(started).inDays;
          return days < 0 ? 0 : days;
        }(),
      };
    }

    return {
      ...userRes,
      'stats': stats,
      'total_sent': totalSent,
      'frames': frames.take(5).toList(),
      'cars': cars.take(5).toList(),
      'gifts': gifts.take(10).toList(),
      'cp_data': cpData,
    };
  } catch (e, st) {
    await AppTelemetry.recordError(
      e,
      st,
      reason: 'publicUserProfileProvider',
      keys: {'user_id': userId},
    );
    debugPrint('Error in publicUserProfileProvider: $e');
    return null;
  }
}

class UserBadgeModel {
  final String name;
  final String imageUrl;
  final int? level;
  final String type;
  final int priority;
  final String? refId;
  final bool isEquipped;

  UserBadgeModel({
    required this.name,
    required this.imageUrl,
    this.level,
    required this.type,
    this.priority = 100,
    this.refId,
    this.isEquipped = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'imageUrl': imageUrl,
    'level': level,
    'type': type,
    'priority': priority,
    'refId': refId,
    'isEquipped': isEquipped,
  };

  factory UserBadgeModel.fromJson(Map<String, dynamic> json) {
    return UserBadgeModel(
      name: json['name']?.toString() ?? '',
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString() ?? '',
      level: (json['level'] as num?)?.toInt(),
      type: json['type']?.toString() ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 100,
      refId: json['refId']?.toString(),
      isEquipped: json['isEquipped'] == true,
    );
  }
}

String _shopCategoryName(dynamic raw) {
  if (raw is Map) return raw['name']?.toString() ?? '';
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map) return first['name']?.toString() ?? '';
  }
  return '';
}

bool _inventoryCategoryExcludedFromBadgeRow(String category) {
  final c = category.toLowerCase();
  return c == 'profile photo frame' ||
      c == 'car' ||
      c == 'entrance show' ||
      c.contains('bubble') ||
      c.contains('gift') ||
      c.contains('lucky') ||
      c.contains('profile card');
}

bool _inventoryItemIsTitle(String category, String sourceType, String name) {
  if (_inventoryCategoryExcludedFromBadgeRow(category)) return false;
  final c = category.toLowerCase();
  final n = name.toLowerCase();
  if (c.contains('title') ||
      c.contains('nameplate') ||
      c.contains('name plate')) {
    return true;
  }
  if (n.contains('title')) return true;
  return false;
}

bool _inventoryItemIsMedal(String category, String sourceType) {
  final c = category.toLowerCase();
  final s = sourceType.toLowerCase();
  return s == 'medal' ||
      c.contains('medal') ||
      (c.contains('badge') && !c.contains('title'));
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty) return _asMap(raw.first);
  return null;
}

Future<List<UserBadgeModel>> fetchUserBadges(
  T Function<T>(ProviderListenable<T> provider) watch,
  String userId,
) async {
  try {
    final List<UserBadgeModel> badges = [];

    final userRes = await supabase
        .from('users')
        .select(
          'wealth_level, charm_level, vip_level, family_id, cp_partner_id',
        )
        .eq('id', userId)
        .maybeSingle();

    if (userRes != null) {
      final wealthLevel = (userRes['wealth_level'] as num?)?.toInt() ?? 1;
      final wealthBadge = await watch(wealthBadgeProvider(wealthLevel).future);
      if (wealthBadge != null && wealthBadge.trim().isNotEmpty) {
        badges.add(
          UserBadgeModel(
            name: 'Wealth Lv.$wealthLevel',
            imageUrl: wealthBadge,
            level: wealthLevel,
            type: 'wealth',
            priority: 1,
          ),
        );
      }

      final charmLevel = (userRes['charm_level'] as num?)?.toInt() ?? 1;
      final charmBadge = await watch(charmBadgeProvider(charmLevel).future);
      if (charmBadge != null && charmBadge.trim().isNotEmpty) {
        badges.add(
          UserBadgeModel(
            name: 'Charm Lv.$charmLevel',
            imageUrl: charmBadge,
            level: charmLevel,
            type: 'charm',
            priority: 2,
          ),
        );
      }

      final vipLevel = (userRes['vip_level'] as num?)?.toInt() ?? 0;
      if (vipLevel > 0) {
        final vipBadge = await supabase
            .from('vip_level_assets')
            .select('image_url')
            .eq('feature_key', 'has_vip_title')
            .eq('level', vipLevel)
            .maybeSingle();

        if (vipBadge?['image_url'] != null) {
          badges.add(
            UserBadgeModel(
              name: 'VIP $vipLevel',
              imageUrl: vipBadge!['image_url'],
              type: 'vip',
              priority: 0,
            ),
          );
        }
      }

      final familyId = userRes['family_id'];
      if (familyId != null) {
        final familyRes = await supabase
            .from('families')
            .select('level')
            .eq('id', familyId)
            .maybeSingle();

        if (familyRes != null) {
          final familyLevel = (familyRes['level'] as num?)?.toInt() ?? 1;
          final familyBadge = await watch(
            familyBadgeProvider(familyLevel).future,
          );
          if (familyBadge != null && familyBadge.trim().isNotEmpty) {
            badges.add(
              UserBadgeModel(
                name: 'Family Lv.$familyLevel',
                imageUrl: familyBadge,
                level: familyLevel,
                type: 'family',
                priority: 4,
              ),
            );
          }
        }
      }

      final coupleRes = await supabase
          .from('couples')
          .select('cp_level')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .maybeSingle();

      if (coupleRes != null) {
        final cpLevel = (coupleRes['cp_level'] as num?)?.toInt() ?? 1;
        final cpConfig = await supabase
            .from('cp_level_configs')
            .select('badge_url')
            .eq('level', cpLevel)
            .maybeSingle();

        if (cpConfig?['badge_url'] != null) {
          badges.add(
            UserBadgeModel(
              name: 'CP Lv.$cpLevel',
              imageUrl: cpConfig!['badge_url'],
              level: cpLevel,
              type: 'cp',
              priority: 3,
            ),
          );
        }
      }

      try {
        Map<String, dynamic>? agency;
        final owned = await supabase
            .from('agencies')
            .select('id, name, owner_id')
            .eq('owner_id', userId)
            .maybeSingle();
        if (owned != null) {
          agency = Map<String, dynamic>.from(owned);
        } else {
          final membership = await supabase
              .from('agency_members')
              .select('agency_id, agencies:agency_id(id, name, owner_id)')
              .eq('user_id', userId)
              .limit(1)
              .maybeSingle();
          final nested = membership?['agencies'];
          if (nested is Map) {
            agency = Map<String, dynamic>.from(nested);
          }
        }

        if (agency != null) {
          final agencyId = agency['id']?.toString() ?? '';
          final agencyName =
              (agency['name']?.toString().trim().isNotEmpty ?? false)
              ? agency['name'].toString().trim()
              : 'Agency';
          final ownerId = agency['owner_id']?.toString() ?? '';

          var totalExp = 0;
          if (ownerId.isNotEmpty) {
            final earnings = await supabase
                .from('earning_logs')
                .select('agency_amount')
                .eq('agency_owner_id', ownerId);
            for (final row in earnings as List) {
              totalExp += (row['agency_amount'] as num?)?.toInt() ?? 0;
            }
          }
          if (agencyId.isNotEmpty) {
            final ranking = await supabase
                .from('agency_rankings')
                .select('score')
                .eq('agency_id', agencyId)
                .eq('ranking_type', 'weekly')
                .maybeSingle();
            final rankScore = (ranking?['score'] as num?)?.toInt() ?? 0;
            if (rankScore > totalExp) totalExp = rankScore;
          }

          final levelConfigs = await watch(agencyLevelConfigsProvider.future);
          final agencyLevel = agencyLevelFromExp(levelConfigs, totalExp);
          final levelConfig = agencyConfigForLevel(levelConfigs, agencyLevel);
          final badgeUrl = levelConfig == null
              ? null
              : agencyBadgeUrl(levelConfig);
          if (badgeUrl != null && badgeUrl.trim().isNotEmpty) {
            badges.add(
              UserBadgeModel(
                name: agencyName,
                imageUrl: badgeUrl,
                level: agencyLevel,
                type: 'agency',
                priority: 5,
                refId: agencyId.isNotEmpty ? agencyId : null,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching agency badge: $e');
      }
    }

    final inventoryRes = await supabase
        .from('user_inventory')
        .select(
          'is_equipped, shop_items(name, image_url, source_type, shop_categories(name))',
        )
        .eq('user_id', userId)
        .or(
          'expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}',
        );

    for (final item in inventoryRes as List) {
      try {
        final si = _asMap(item['shop_items']);
        if (si == null) continue;

        final imageUrl = si['image_url']?.toString().trim() ?? '';
        if (imageUrl.isEmpty) continue;

        final isEquipped = item['is_equipped'] == true;
        final category = _shopCategoryName(si['shop_categories']).toLowerCase();
        final sourceType = si['source_type']?.toString().toLowerCase() ?? '';
        final name = si['name']?.toString() ?? 'Item';

        if (_inventoryItemIsTitle(category, sourceType, name)) {
          if (!isEquipped) continue;
          badges.add(
            UserBadgeModel(
              name: name,
              imageUrl: imageUrl,
              type: 'title',
              priority: 35,
              isEquipped: true,
            ),
          );
        } else if (_inventoryItemIsMedal(category, sourceType)) {
          if (!isEquipped) continue;
          badges.add(
            UserBadgeModel(
              name: name,
              imageUrl: imageUrl,
              type: 'medal',
              priority: 45,
              isEquipped: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error parsing inventory badge row: $e');
      }
    }

    badges.sort((a, b) => a.priority.compareTo(b.priority));
    return badges;
  } catch (e) {
    debugPrint('Error in fetchUserBadges: $e');
    return [];
  }
}

final userBadgesProvider = FutureProvider.autoDispose
    .family<List<UserBadgeModel>, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      try {
        final cachedMaps = HiveCacheService.loadBadges(userId);
        if (cachedMaps != null) {
          final cached = cachedMaps.map(UserBadgeModel.fromJson).toList();
          Future(() async {
            try {
              final remote = await fetchUserBadges(ref.watch, userId);
              final changed = await HiveCacheService.saveBadges(
                userId,
                remote.map((b) => b.toJson()).toList(),
              );
              if (changed) {
                ref.invalidateSelf();
              }
            } catch (e) {
              debugPrint('[userBadgesProvider] bg refresh failed: $e');
            }
          });
          return cached;
        }

        final remote = await fetchUserBadges(ref.watch, userId);
        await HiveCacheService.saveBadges(
          userId,
          remote.map((b) => b.toJson()).toList(),
        );
        return remote;
      } catch (e) {
        debugPrint('Error in userBadgesProvider: $e');
        return [];
      }
    });

Future<Map<String, String?>?> fetchUserEquippedFrame(String userId) async {
  try {
    final inventoryRes = await supabase
        .from('user_inventory')
        .select('shop_items(image_url, svga_url, shop_categories(name))')
        .eq('user_id', userId)
        .eq('is_equipped', true)
        .or(
          'expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}',
        );

    for (var item in inventoryRes as List) {
      final si = item['shop_items'] as Map<String, dynamic>?;
      if (si == null) continue;
      final cat =
          si['shop_categories']?['name']?.toString().toLowerCase() ?? '';
      final isPhotoFrame =
          cat == 'profile photo frame' ||
          (cat.contains('frame') && !cat.contains('card'));
      if (!isPhotoFrame) continue;
      return {
        'image_url': si['image_url'] as String?,
        'svga_url': si['svga_url'] as String?,
      };
    }

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
            .select('frame_url')
            .eq('level', cpLevel)
            .maybeSingle();
        if (cpConfig?['frame_url'] != null) {
          return {
            'image_url': cpConfig!['frame_url'] as String?,
            'svga_url': null,
          };
        }
      }
    }

    return null;
  } catch (e) {
    debugPrint('Error in fetchUserEquippedFrame: $e');
    return null;
  }
}

final userEquippedFrameProvider = FutureProvider.autoDispose
    .family<Map<String, String?>?, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      final cached = HiveCacheService.loadEquippedFrame(userId);
      if (cached != null) {
        Future(() async {
          try {
            final before = HiveCacheService.loadEquipped(
              userId,
            )?['fingerprint'];
            final remote = await fetchUserEquippedFrame(userId);
            await HiveCacheService.patchEquippedFrame(userId, remote);
            final after = HiveCacheService.loadEquipped(userId)?['fingerprint'];
            if (before != after) {
              ref.invalidateSelf();
            }
          } catch (e) {
            debugPrint('[userEquippedFrameProvider] bg refresh failed: $e');
          }
        });
        final image = cached['image_url']?.trim();
        final svga = cached['svga_url']?.trim();
        if ((image == null || image.isEmpty) &&
            (svga == null || svga.isEmpty)) {
          return null;
        }
        return cached;
      }

      final remote = await fetchUserEquippedFrame(userId);
      await HiveCacheService.patchEquippedFrame(userId, remote);
      return remote;
    });
