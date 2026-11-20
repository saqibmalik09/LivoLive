import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';

/// Seated users' frames and badges, shared by every avatar on the room.
///
/// The join snapshot teaches it when the gateway already sent wear. Otherwise
/// one batched read fills every visible seat. A hit skips the network, so
/// leaving and re-entering the room does not fetch again.
class SeatWearCache {
  SeatWearCache._();

  static const Duration _ttl = Duration(minutes: 10);
  static const Duration _failCooldown = Duration(seconds: 3);
  static const int _batchCap = 24;

  static final Map<String, _Slot<Map<String, String?>?>> _frames = {};
  static final Map<String, _Slot<List<Map<String, dynamic>>>> _badges = {};
  static final Map<String, DateTime> _failedAt = {};
  static final Map<String, String> _persisted = {};
  static final Set<String> _pending = {};
  static final Map<String, List<Completer<Map<String, String?>?>>> _frameWait =
      {};
  static final Map<String, List<Completer<List<Map<String, dynamic>>>>>
  _badgeWait = {};

  static Future<void>? _kick;
  static _WearConfigs? _configs;

  static void forget(String userId) {
    if (userId.isEmpty) return;
    _frames.remove(userId);
    _badges.remove(userId);
    _failedAt.remove(userId);
    _persisted.remove('f:$userId');
    _persisted.remove('b:$userId');
  }

  /// Sync hit. [known] is false when this user has not been loaded yet.
  static ({bool known, Map<String, String?>? frame}) frameNow(String userId) {
    final slot = _live(_frames, userId);
    if (slot == null) return (known: false, frame: null);
    return (known: true, frame: slot.value);
  }

  /// Sync hit. Null when badges have not been loaded yet (empty is a hit).
  static List<Map<String, dynamic>>? badgesNow(String userId) {
    return _live(_badges, userId)?.value;
  }

  static Map<String, String?>? rememberHiveFrame(
    String userId,
    Map<String, String?> cached,
  ) {
    final frame = _cleanFrame(cached);
    _frames[userId] = _Slot(frame, DateTime.now());
    return frame;
  }

  static void rememberBadges(String userId, List<Map<String, dynamic>> badges) {
    _badges[userId] = _Slot(
      badges.map((b) => Map<String, dynamic>.from(b)).toList(growable: false),
      DateTime.now(),
    );
  }

  static Future<Map<String, String?>?> frameFor(String userId) {
    final slot = _live(_frames, userId);
    if (slot != null) return Future.value(slot.value);
    if (_cooling(userId)) return Future.value(null);
    final waiter = Completer<Map<String, String?>?>();
    (_frameWait[userId] ??= []).add(waiter);
    _pending.add(userId);
    _arm();
    return waiter.future;
  }

  static Future<List<Map<String, dynamic>>> badgesFor(String userId) {
    final slot = _live(_badges, userId);
    if (slot != null) {
      return Future.value(List<Map<String, dynamic>>.from(slot.value));
    }
    if (_cooling(userId)) return Future.value(const []);
    final waiter = Completer<List<Map<String, dynamic>>>();
    (_badgeWait[userId] ??= []).add(waiter);
    _pending.add(userId);
    _arm();
    return waiter.future;
  }

  /// Seed from the seat rows already in the snapshot, then batch whoever is missing.
  static void ingestSeats(Iterable<dynamic> seats) {
    final need = <String>[];
    for (final seat in seats) {
      if (seat is! Map) continue;
      final user = seat['user'] is Map
          ? Map<String, dynamic>.from(seat['user'] as Map)
          : <String, dynamic>{};
      final userId = (user['id'] ?? seat['user_id'])?.toString() ?? '';
      if (userId.isEmpty) continue;

      var frameKnown = _live(_frames, userId) != null;
      var badgesKnown = _live(_badges, userId) != null;

      if (!frameKnown &&
          (user.containsKey('frame_image_url') ||
              user.containsKey('frame_svga_url'))) {
        final frame = _cleanFrame({
          'image_url': user['frame_image_url'],
          'svga_url': user['frame_svga_url'],
        });
        _frames[userId] = _Slot(frame, DateTime.now());
        _persistFrame(userId, frame);
        frameKnown = true;
      }
      if (!badgesKnown && user['badges'] is List) {
        final badges = _badgeMaps(user['badges']);
        rememberBadges(userId, badges);
        _persistBadges(userId, badges);
        badgesKnown = true;
      }
      if (!frameKnown) {
        final hive = HiveCacheService.loadEquippedFrame(userId);
        if (hive != null) {
          rememberHiveFrame(userId, hive);
          frameKnown = true;
        }
      }
      if (!badgesKnown) {
        final hive = HiveCacheService.loadBadges(userId);
        if (hive != null) {
          rememberBadges(userId, hive);
          badgesKnown = true;
        }
      }
      if (!frameKnown || !badgesKnown) need.add(userId);
    }
    if (need.isNotEmpty) unawaited(ensure(need));
  }

  static Future<void> ensure(Iterable<String> userIds) {
    for (final id in userIds) {
      if (id.isEmpty || _cooling(id)) continue;
      if (_live(_frames, id) != null && _live(_badges, id) != null) continue;
      _pending.add(id);
    }
    if (_pending.isEmpty) return Future.value();
    return _arm();
  }

  static Future<void> _arm() {
    return _kick ??= _drain();
  }

  static Future<void> _drain() async {
    await Future<void>.delayed(Duration.zero);
    final ids = _pending.take(_batchCap).toList(growable: false);
    _pending.removeAll(ids);
    try {
      if (ids.isNotEmpty) await _fetch(ids);
    } catch (e) {
      debugPrint('[SeatWear] batch failed: $e');
      _markFailed(ids);
    } finally {
      _complete(_frameWait, ids, (id) => _frames[id]?.value);
      _complete(
        _badgeWait,
        ids,
        (id) => List<Map<String, dynamic>>.from(
          _badges[id]?.value ?? const <Map<String, dynamic>>[],
        ),
      );
      _kick = null;
      if (_pending.isNotEmpty) _arm();
    }
  }

  static Future<void> _fetch(List<String> ids) async {
    final configsFuture = _loadConfigs();
    final usersFuture = _users(ids);
    final inventoryFuture = _inventory(ids);
    final couplesFuture = _couples(ids);

    final inventory = await inventoryFuture;
    final couples = await couplesFuture;
    final configs = await configsFuture;
    if (!inventory.ok) {
      _markFailed(ids);
      return;
    }
    _storeFrames(ids, inventory.rows, couples.rows, configs);
    _complete(_frameWait, ids, (id) => _frames[id]?.value);

    final users = await usersFuture;
    if (!users.ok) {
      debugPrint('[SeatWear] user rows missing; level badges skipped');
    }

    final agencies = await _agencies(ids);
    final members = await _members(ids);
    final byUser = _agencyByUser(ids, agencies.rows, members.rows);
    final agencyIds = byUser.values
        .map((a) => a.id)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final rankings = agencyIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await _rankings(agencyIds)).rows;
    final owners = byUser.values
        .map((a) => a.ownerId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(16);
    final expByOwner = <String, int>{};
    await Future.wait(
      owners.map((owner) async {
        expByOwner[owner] = await _agencyExp(owner);
      }),
    );

    _storeBadges(
      ids: ids,
      users: users.rows,
      inventory: inventory.rows,
      couples: couples.rows,
      configs: configs,
      agencyByUser: byUser,
      rankings: rankings,
      expByOwner: expByOwner,
    );
    for (final id in ids) {
      _failedAt.remove(id);
    }
  }

  static void _storeFrames(
    List<String> ids,
    List<Map<String, dynamic>> inventory,
    List<Map<String, dynamic>> couples,
    _WearConfigs configs,
  ) {
    final cpLevel = _cpLevelByUser(couples);
    for (final id in ids) {
      Map<String, String?>? frame;
      for (final row in inventory) {
        if (row['user_id']?.toString() != id) continue;
        if (!_rowActive(row)) continue;
        final shop = _asMap(row['shop_items']);
        if (shop == null) continue;
        final category = _shopCategoryName(
          shop['shop_categories'],
        ).toLowerCase();
        final isFrame =
            category == 'profile photo frame' ||
            (category.contains('frame') && !category.contains('card'));
        if (!isFrame) continue;
        frame = _cleanFrame({
          'image_url': shop['image_url'],
          'svga_url': shop['svga_url'],
        });
        if (frame != null) break;
      }
      if (frame == null) {
        final level = cpLevel[id] ?? 0;
        final cpFrame = level > 0 ? configs.cpFrame[level] : null;
        if (cpFrame != null && cpFrame.isNotEmpty) {
          frame = {'image_url': cpFrame, 'svga_url': null};
        }
      }
      _frames[id] = _Slot(frame, DateTime.now());
      _persistFrame(id, frame);
    }
  }

  static void _storeBadges({
    required List<String> ids,
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> inventory,
    required List<Map<String, dynamic>> couples,
    required _WearConfigs configs,
    required Map<String, _AgencyRef> agencyByUser,
    required List<Map<String, dynamic>> rankings,
    required Map<String, int> expByOwner,
  }) {
    final userById = <String, Map<String, dynamic>>{};
    for (final row in users) {
      final id = row['id']?.toString();
      if (id != null) userById[id] = row;
    }
    final rankByAgency = <String, int>{};
    for (final row in rankings) {
      final id = row['agency_id']?.toString();
      if (id == null) continue;
      final score = (row['score'] as num?)?.toInt() ?? 0;
      final prev = rankByAgency[id] ?? 0;
      if (score > prev) rankByAgency[id] = score;
    }
    final cpLevel = _cpLevelByUser(couples);

    for (final id in ids) {
      final badges = <Map<String, dynamic>>[];
      final user = userById[id];
      if (user != null) {
        final wealthLevel = (user['wealth_level'] as num?)?.toInt() ?? 1;
        final wealthUrl = configs.wealth[wealthLevel];
        if (wealthUrl != null && wealthUrl.isNotEmpty) {
          badges.add({
            'name': 'Wealth Lv.$wealthLevel',
            'imageUrl': wealthUrl,
            'level': wealthLevel,
            'type': 'wealth',
            'priority': 1,
          });
        }
        final charmLevel = (user['charm_level'] as num?)?.toInt() ?? 1;
        final charmUrl = configs.charm[charmLevel];
        if (charmUrl != null && charmUrl.isNotEmpty) {
          badges.add({
            'name': 'Charm Lv.$charmLevel',
            'imageUrl': charmUrl,
            'level': charmLevel,
            'type': 'charm',
            'priority': 2,
          });
        }
        final vipLevel = (user['vip_level'] as num?)?.toInt() ?? 0;
        if (vipLevel > 0) {
          final vipUrl = configs.vip[vipLevel];
          if (vipUrl != null && vipUrl.isNotEmpty) {
            badges.add({
              'name': 'VIP $vipLevel',
              'imageUrl': vipUrl,
              'type': 'vip',
              'priority': 0,
            });
          }
        }
        final family = _asMap(user['families']);
        final familyLevel = (family?['level'] as num?)?.toInt();
        if (familyLevel != null) {
          final familyUrl = configs.familyBadge(familyLevel);
          if (familyUrl != null && familyUrl.isNotEmpty) {
            badges.add({
              'name': 'Family Lv.$familyLevel',
              'imageUrl': familyUrl,
              'level': familyLevel,
              'type': 'family',
              'priority': 4,
            });
          }
        }
        final level = cpLevel[id];
        if (level != null) {
          final badgeLevel = level > 0 ? level : 1;
          final cpUrl = configs.cpBadge[badgeLevel];
          if (cpUrl != null && cpUrl.isNotEmpty) {
            badges.add({
              'name': 'CP Lv.$badgeLevel',
              'imageUrl': cpUrl,
              'level': badgeLevel,
              'type': 'cp',
              'priority': 3,
            });
          }
        }
      }

      final agency = agencyByUser[id];
      if (agency != null && configs.agency.isNotEmpty) {
        final rankScore = rankByAgency[agency.id] ?? 0;
        final ownerExp = expByOwner[agency.ownerId] ?? 0;
        final total = ownerExp > rankScore ? ownerExp : rankScore;
        final agencyLevel = agencyLevelFromExp(configs.agency, total);
        if (agencyLevel > 0) {
          Map<String, dynamic>? levelConfig;
          for (final config in configs.agency) {
            if ((config['level'] as num?)?.toInt() == agencyLevel) {
              levelConfig = config;
              break;
            }
          }
          final badgeUrl = levelConfig == null
              ? null
              : agencyBadgeUrl(levelConfig);
          if (badgeUrl != null && badgeUrl.trim().isNotEmpty) {
            badges.add({
              'name': agency.name,
              'imageUrl': badgeUrl,
              'level': agencyLevel,
              'type': 'agency',
              'priority': 5,
              'refId': agency.id,
            });
          }
        }
      }

      for (final row in inventory) {
        if (row['user_id']?.toString() != id || !_rowActive(row)) continue;
        final shop = _asMap(row['shop_items']);
        if (shop == null) continue;
        final imageUrl = shop['image_url']?.toString().trim() ?? '';
        if (imageUrl.isEmpty) continue;
        final category = _shopCategoryName(shop['shop_categories']);
        final source = shop['source_type']?.toString().toLowerCase() ?? '';
        final name = shop['name']?.toString() ?? 'Item';
        if (_isTitle(category, name)) {
          badges.add({
            'name': name,
            'imageUrl': imageUrl,
            'type': 'title',
            'priority': 35,
            'isEquipped': true,
          });
        } else if (_isMedal(category, source)) {
          badges.add({
            'name': name,
            'imageUrl': imageUrl,
            'type': 'medal',
            'priority': 45,
            'isEquipped': true,
          });
        }
      }

      badges.sort(
        (a, b) => ((a['priority'] as num?)?.toInt() ?? 100).compareTo(
          (b['priority'] as num?)?.toInt() ?? 100,
        ),
      );
      rememberBadges(id, badges);
      _persistBadges(id, badges);
    }
  }

  static Future<_WearConfigs> _loadConfigs() async {
    final cached = _configs;
    if (cached != null) return cached;
    final results = await Future.wait([
      _rows(
        () => Supabase.instance.client
            .from('level_configs')
            .select('level, badge_url')
            .eq('category', 'user_wealth'),
      ),
      _rows(
        () => Supabase.instance.client
            .from('charm_level_assets')
            .select('level, image_url')
            .eq('feature_key', 'badge'),
      ),
      _rows(
        () => Supabase.instance.client
            .from('vip_level_assets')
            .select('level, image_url')
            .eq('feature_key', 'has_vip_title'),
      ),
      _rows(
        () => Supabase.instance.client
            .from('family_level_assets')
            .select('level, image_url')
            .eq('feature_key', 'badge'),
      ),
      _rows(
        () => Supabase.instance.client
            .from('cp_level_configs')
            .select('level, badge_url, frame_url'),
      ),
      _rows(
        () => Supabase.instance.client
            .from('agency_level_configs')
            .select('level, min_exp, badge_url')
            .order('level', ascending: true),
      ),
    ]);
    final next = _WearConfigs(
      wealth: _urlByLevel(results[0].rows, 'badge_url'),
      charm: _urlByLevel(results[1].rows, 'image_url'),
      vip: _urlByLevel(results[2].rows, 'image_url'),
      family: results[3].rows,
      cpBadge: _urlByLevel(results[4].rows, 'badge_url'),
      cpFrame: _urlByLevel(results[4].rows, 'frame_url'),
      agency: results[5].rows,
    );
    if (results.every((r) => r.ok)) _configs = next;
    return next;
  }

  static Future<_Rows> _users(List<String> ids) async {
    final embedded = await _rows(
      () => Supabase.instance.client
          .from('users')
          .select(
            'id, wealth_level, charm_level, vip_level, family_id, families(level)',
          )
          .inFilter('id', ids),
    );
    if (embedded.ok) return embedded;
    return _rows(
      () => Supabase.instance.client
          .from('users')
          .select('id, wealth_level, charm_level, vip_level, family_id')
          .inFilter('id', ids),
    );
  }

  static Future<_Rows> _inventory(List<String> ids) async {
    final now = DateTime.now().toIso8601String();
    final filtered = await _rows(
      () => Supabase.instance.client
          .from('user_inventory')
          .select(
            'user_id, is_equipped, expires_at, shop_items(name, image_url, svga_url, source_type, shop_categories(name))',
          )
          .inFilter('user_id', ids)
          .eq('is_equipped', true)
          .or('expires_at.is.null,expires_at.gt.$now'),
    );
    if (filtered.ok) return filtered;
    return _rows(
      () => Supabase.instance.client
          .from('user_inventory')
          .select(
            'user_id, is_equipped, expires_at, shop_items(name, image_url, svga_url, source_type, shop_categories(name))',
          )
          .inFilter('user_id', ids)
          .eq('is_equipped', true),
    );
  }

  static Future<_Rows> _couples(List<String> ids) {
    final list = ids.join(',');
    return _rows(
      () => Supabase.instance.client
          .from('couples')
          .select('user1_id, user2_id, cp_level')
          .or('user1_id.in.($list),user2_id.in.($list)'),
    );
  }

  static Future<_Rows> _agencies(List<String> ids) {
    return _rows(
      () => Supabase.instance.client
          .from('agencies')
          .select('id, name, owner_id')
          .inFilter('owner_id', ids),
    );
  }

  static Future<_Rows> _members(List<String> ids) {
    return _rows(
      () => Supabase.instance.client
          .from('agency_members')
          .select('user_id, agencies:agency_id(id, name, owner_id)')
          .inFilter('user_id', ids),
    );
  }

  static Future<_Rows> _rankings(List<String> agencyIds) {
    return _rows(
      () => Supabase.instance.client
          .from('agency_rankings')
          .select('agency_id, score')
          .inFilter('agency_id', agencyIds)
          .eq('ranking_type', 'weekly'),
    );
  }

  static Future<int> _agencyExp(String ownerId) async {
    try {
      final total = await Supabase.instance.client
          .rpc('agency_total_exp', params: {'p_owner_id': ownerId})
          .timeout(const Duration(milliseconds: 800));
      return (total as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<_Rows> _rows(Future<dynamic> Function() query) async {
    try {
      final raw = await query();
      if (raw is! List) return const _Rows(ok: true, rows: []);
      return _Rows(
        ok: true,
        rows: raw
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false),
      );
    } catch (e) {
      debugPrint('[SeatWear] query failed: $e');
      return const _Rows(ok: false, rows: []);
    }
  }

  static Map<String, _AgencyRef> _agencyByUser(
    List<String> ids,
    List<Map<String, dynamic>> owned,
    List<Map<String, dynamic>> members,
  ) {
    final out = <String, _AgencyRef>{};
    for (final row in owned) {
      final ownerId = row['owner_id']?.toString() ?? '';
      final id = row['id']?.toString() ?? '';
      if (ownerId.isEmpty || id.isEmpty || !ids.contains(ownerId)) continue;
      out[ownerId] = _AgencyRef(
        id: id,
        name: _agencyName(row['name']),
        ownerId: ownerId,
      );
    }
    for (final row in members) {
      final userId = row['user_id']?.toString() ?? '';
      if (userId.isEmpty || out.containsKey(userId)) continue;
      final agency = _asMap(row['agencies']);
      final id = agency?['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      out[userId] = _AgencyRef(
        id: id,
        name: _agencyName(agency?['name']),
        ownerId: agency?['owner_id']?.toString() ?? '',
      );
    }
    return out;
  }

  static Map<String, int> _cpLevelByUser(List<Map<String, dynamic>> couples) {
    final out = <String, int>{};
    for (final row in couples) {
      final level = (row['cp_level'] as num?)?.toInt() ?? 0;
      for (final key in ['user1_id', 'user2_id']) {
        final id = row[key]?.toString();
        if (id == null || id.isEmpty) continue;
        final prev = out[id];
        if (prev == null || level > prev) out[id] = level;
      }
    }
    return out;
  }

  static Map<int, String> _urlByLevel(
    List<Map<String, dynamic>> rows,
    String field,
  ) {
    final out = <int, String>{};
    for (final row in rows) {
      final level = (row['level'] as num?)?.toInt();
      final url = row[field]?.toString().trim() ?? '';
      if (level == null || url.isEmpty) continue;
      out[level] = url;
    }
    return out;
  }

  static bool _rowActive(Map<String, dynamic> row) {
    if (row['is_equipped'] == false) return false;
    final raw = row['expires_at'];
    if (raw == null) return true;
    final expires = DateTime.tryParse(raw.toString());
    if (expires == null) return true;
    return expires.isAfter(DateTime.now());
  }

  static void _persistFrame(String userId, Map<String, String?>? frame) {
    final fp = '${frame?['image_url']}|${frame?['svga_url']}';
    final key = 'f:$userId';
    if (_persisted[key] == fp) return;
    _persisted[key] = fp;
    unawaited(HiveCacheService.patchEquippedFrame(userId, frame));
  }

  static void _persistBadges(String userId, List<Map<String, dynamic>> badges) {
    final fp = badges
        .map((b) => '${b['type']}:${b['imageUrl'] ?? b['image_url']}')
        .join('|');
    final key = 'b:$userId';
    if (_persisted[key] == fp) return;
    _persisted[key] = fp;
    unawaited(HiveCacheService.saveBadges(userId, badges));
  }

  static void _markFailed(List<String> ids) {
    final now = DateTime.now();
    for (final id in ids) {
      _failedAt[id] = now;
    }
  }

  static bool _cooling(String userId) {
    final at = _failedAt[userId];
    if (at == null) return false;
    if (DateTime.now().difference(at) > _failCooldown) {
      _failedAt.remove(userId);
      return false;
    }
    return true;
  }

  static _Slot<T>? _live<T>(Map<String, _Slot<T>> map, String userId) {
    final slot = map[userId];
    if (slot == null) return null;
    if (DateTime.now().difference(slot.at) > _ttl) {
      map.remove(userId);
      return null;
    }
    return slot;
  }

  static void _complete<T>(
    Map<String, List<Completer<T>>> waiters,
    List<String> ids,
    T Function(String id) value,
  ) {
    for (final id in ids) {
      final pending = waiters.remove(id);
      if (pending == null) continue;
      final next = value(id);
      for (final waiter in pending) {
        if (!waiter.isCompleted) waiter.complete(next);
      }
    }
  }

  static Map<String, String?>? _cleanFrame(Map<dynamic, dynamic>? raw) {
    if (raw == null) return null;
    final image = raw['image_url']?.toString().trim() ?? '';
    final svga = raw['svga_url']?.toString().trim() ?? '';
    if (image.isEmpty && svga.isEmpty) return null;
    return {
      'image_url': image.isEmpty ? null : image,
      'svga_url': svga.isEmpty ? null : svga,
    };
  }

  static List<Map<String, dynamic>> _badgeMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty) return _asMap(raw.first);
    return null;
  }

  static String _shopCategoryName(dynamic raw) {
    final map = _asMap(raw);
    return map?['name']?.toString() ?? '';
  }

  static String _agencyName(dynamic raw) {
    final name = raw?.toString().trim() ?? '';
    return name.isEmpty ? 'Agency' : name;
  }

  static bool _excluded(String category) {
    final c = category.toLowerCase();
    return c == 'profile photo frame' ||
        c == 'car' ||
        c == 'entrance show' ||
        c.contains('bubble') ||
        c.contains('gift') ||
        c.contains('lucky') ||
        c.contains('profile card');
  }

  static bool _isTitle(String category, String name) {
    if (_excluded(category)) return false;
    final c = category.toLowerCase();
    final n = name.toLowerCase();
    if (c.contains('title') ||
        c.contains('nameplate') ||
        c.contains('name plate')) {
      return true;
    }
    return n.contains('title');
  }

  static bool _isMedal(String category, String sourceType) {
    final c = category.toLowerCase();
    final s = sourceType.toLowerCase();
    return s == 'medal' ||
        c.contains('medal') ||
        (c.contains('badge') && !c.contains('title'));
  }
}

class _Slot<T> {
  _Slot(this.value, this.at);
  final T value;
  final DateTime at;
}

class _Rows {
  const _Rows({required this.ok, required this.rows});
  final bool ok;
  final List<Map<String, dynamic>> rows;
}

class _AgencyRef {
  const _AgencyRef({
    required this.id,
    required this.name,
    required this.ownerId,
  });
  final String id;
  final String name;
  final String ownerId;
}

class _WearConfigs {
  const _WearConfigs({
    required this.wealth,
    required this.charm,
    required this.vip,
    required this.family,
    required this.cpBadge,
    required this.cpFrame,
    required this.agency,
  });

  final Map<int, String> wealth;
  final Map<int, String> charm;
  final Map<int, String> vip;
  final List<Map<String, dynamic>> family;
  final Map<int, String> cpBadge;
  final Map<int, String> cpFrame;
  final List<Map<String, dynamic>> agency;

  String? familyBadge(int level) {
    String? best;
    var bestLevel = -1;
    String? lowest;
    var lowestLevel = 1 << 30;
    for (final row in family) {
      final rowLevel = (row['level'] as num?)?.toInt();
      final url = row['image_url']?.toString().trim() ?? '';
      if (rowLevel == null || url.isEmpty) continue;
      if (rowLevel < lowestLevel) {
        lowestLevel = rowLevel;
        lowest = url;
      }
      if (rowLevel <= level && rowLevel >= bestLevel) {
        bestLevel = rowLevel;
        best = url;
      }
    }
    return best ?? lowest;
  }
}
