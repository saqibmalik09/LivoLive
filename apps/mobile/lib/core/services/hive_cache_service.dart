import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveCacheService {
  HiveCacheService._();

  static const String _uiBoxName = 'app_ui';
  static const String roomCoversBoxName = 'room_covers';
  static const String userMediaBoxName = 'user_media';

  static const String _bannersKeyPrefix = 'banners_';
  static const String _partyConfigKey = 'party_config_v1';
  static const String _gamesConfigsKey = 'game_configs_v5';
  static const String _gameConfigsFpKey = 'game_configs_fp_v5';
  static const String _recentGamesKey = 'recent_room_games_v1';
  static const int recentGamesMax = 4;
  static const String _homeGamesRowKey = 'home_games_row_v1';
  static const String _homeGamesRowFpKey = 'home_games_row_fp_v1';
  static const String _suGamesHubKey = 'su_games_hub_v1';
  static const String _suGamesHubFpKey = 'su_games_hub_fp_v1';
  static const String _rankFramesBoxName = 'rank_frames';
  static const String _rankFramesKey = 'frames_v2';

  static Box<String>? _rankFramesBox;

  static const String _roomCoversKey = 'covers_v1';
  static const String _roomCoversIdsKey = 'cover_ids_v1';

  static Box<String>? _uiBox;
  static Box<String>? _coversBox;
  static Box<String>? _userMediaBox;

  static Future<void> init() async {
    _uiBox = await _openBox(_uiBoxName);
    _coversBox = await _openBox(roomCoversBoxName);
    _userMediaBox = await _openBox(userMediaBoxName);
    await Future.wait([
      _uiBox!.delete('rc_supabase_url'),
      _uiBox!.delete('rc_supabase_anon_key'),
    ]);
  }

  static Future<Box<String>> _openBox(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    return Hive.openBox<String>(name);
  }

  static Box<String> get _ui {
    assert(_uiBox != null, 'HiveCacheService.init() not called');
    return _uiBox!;
  }

  static Box<String> get _covers {
    assert(_coversBox != null, 'HiveCacheService.init() not called');
    return _coversBox!;
  }

  static Box<String> get _userMedia {
    assert(_userMediaBox != null, 'HiveCacheService.init() not called');
    return _userMediaBox!;
  }

  static String _equipKey(String userId) => 'equip_$userId';
  static String _profileKey(String userId) => 'profile_$userId';
  static String _backpackKey(String userId) => 'backpack_$userId';
  static String _backpackFpKey(String userId) => 'backpack_fp_$userId';
  static String _badgesKey(String userId) => 'badges_$userId';
  static String _badgesFpKey(String userId) => 'badges_fp_$userId';

  static String _str(dynamic v) => v?.toString() ?? '';

  static final Map<String, Future<void>> _equipLocks = {};

  static Future<void> _withEquipLock(
    String userId,
    Future<void> Function() action,
  ) async {
    final previous = _equipLocks[userId] ?? Future<void>.value();
    late final Future<void> current;
    current = previous.then((_) => action());
    _equipLocks[userId] = current.then((_) {}, onError: (_) {});
    await current;
  }

  static String equipFingerprint(Map<String, dynamic> data) {
    final frame = data['frame'];
    final car = data['car'];
    final entrance = data['entrance'];
    final frameMap = frame is Map ? Map<String, dynamic>.from(frame) : null;
    final carMap = car is Map ? Map<String, dynamic>.from(car) : null;
    final entMap = entrance is Map ? Map<String, dynamic>.from(entrance) : null;
    return [
      _str(frameMap?['image_url']),
      _str(frameMap?['svga_url']),
      _str(carMap?['svga_url']),
      _str(entMap?['patti_url']),
      _str(entMap?['patti_svga']),
    ].join('|');
  }

  static String _bannersKey(String placement) =>
      '$_bannersKeyPrefix${placement}_v1';

  static String _bannersFpKey(String placement) =>
      '$_bannersKeyPrefix${placement}_fp_v1';

  static String bannersFingerprint(List<Map<String, dynamic>> banners) {
    final parts = banners.map((b) {
      return [
        _str(b['id']),
        _str(b['image_url']),
        _str(b['priority']),
        _str(b['is_active']),
        _str(b['placement']),
        _str(b['link_url'] ?? b['action_url']),
        _str(b['room_number']),
        _str(b['party_event_id']),
        _str(b['updated_at']),
      ].join(':');
    }).toList()..sort();
    return parts.join('|');
  }

  static List<Map<String, dynamic>>? loadBanners({String placement = 'top'}) {
    try {
      final raw = _ui.get(_bannersKey(placement));
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadBanners failed: $e');
      return null;
    }
  }

  static Future<bool> saveBanners(
    List<Map<String, dynamic>> banners, {
    String placement = 'top',
  }) async {
    try {
      final fp = bannersFingerprint(banners);
      final existingFp = _ui.get(_bannersFpKey(placement));
      if (existingFp != null && existingFp == fp) return false;
      await Future.wait([
        _ui.put(_bannersKey(placement), jsonEncode(banners)),
        _ui.put(_bannersFpKey(placement), fp),
      ]);
      return true;
    } catch (e) {
      debugPrint('[HiveCache] saveBanners failed: $e');
      return false;
    }
  }

  static Map<String, dynamic>? loadPartyConfig() {
    try {
      final raw = _ui.get(_partyConfigKey);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[HiveCache] loadPartyConfig failed: $e');
      return null;
    }
  }

  static Future<void> savePartyConfig(Map<String, dynamic> config) async {
    try {
      await _ui.put(_partyConfigKey, jsonEncode(config));
    } catch (e) {
      debugPrint('[HiveCache] savePartyConfig failed: $e');
    }
  }

  static String gamesFingerprint(List<Map<String, dynamic>> games) {
    final parts = games.map((g) {
      return [
        _str(g['id']),
        _str(g['slug']),
        _str(g['name'] ?? g['display_name']),
        _str(g['icon_url']),
        _str(g['game_url']),
        _str(g['sort_order']),
        _str(g['webview_height_percent']),
        _str(g['maintenance_mode']),
        _configDataFingerprint(g['config_data']),
        _str(g['category_id']),
        _str(g['category_name']),
        _str(g['category_sort']),
      ].join(':');
    }).toList()..sort();
    return parts.join('|');
  }

  static String _configDataFingerprint(dynamic raw) {
    if (raw is! Map) return '';
    try {
      return jsonEncode(Map<String, dynamic>.from(raw));
    } catch (_) {
      return _str(raw['provider']);
    }
  }

  static Map<String, dynamic>? _normalizeConfigData(dynamic raw) {
    if (raw is! Map) return null;
    try {
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>>? loadGames() {
    try {
      final raw = _ui.get(_gamesConfigsKey);
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadGames failed: $e');
      return null;
    }
  }

  static Future<bool> saveGames(List<Map<String, dynamic>> games) async {
    try {
      final normalized = games.map((g) {
        final cfg = _normalizeConfigData(g['config_data']);
        return {
          'id': g['id']?.toString() ?? '',
          'slug': g['slug']?.toString() ?? '',
          'name': g['name']?.toString() ?? '',
          'display_name':
              g['display_name']?.toString() ?? g['name']?.toString() ?? '',
          'icon_url': g['icon_url']?.toString() ?? '',
          'game_url': g['game_url']?.toString() ?? '',
          'sort_order': g['sort_order'] ?? 0,
          'webview_height_percent': g['webview_height_percent'] ?? 70,
          'maintenance_mode': g['maintenance_mode'] ?? false,
          'maintenance_message': g['maintenance_message']?.toString() ?? '',
          if (cfg != null) 'config_data': cfg,
          if (g['category_id'] != null)
            'category_id': g['category_id']?.toString(),
          if (g['category_name'] != null)
            'category_name': g['category_name']?.toString(),
          if (g['category_sort'] != null) 'category_sort': g['category_sort'],
        };
      }).toList();
      final fp = gamesFingerprint(normalized);
      final existingFp = _ui.get(_gameConfigsFpKey);
      if (existingFp != null && existingFp == fp) return false;
      await Future.wait([
        _ui.put(_gamesConfigsKey, jsonEncode(normalized)),
        _ui.put(_gameConfigsFpKey, fp),
      ]);
      return true;
    } catch (e) {
      debugPrint('[HiveCache] saveGames failed: $e');
      return false;
    }
  }

  static List<String> loadRecentGameIds() {
    try {
      final raw = _ui.get(_recentGamesKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .take(recentGamesMax)
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadRecentGameIds failed: $e');
      return const [];
    }
  }

  static Future<void> pushRecentGameId(String gameId) async {
    final id = gameId.trim();
    if (id.isEmpty) return;
    try {
      final next = <String>[id];
      for (final existing in loadRecentGameIds()) {
        if (existing == id) continue;
        next.add(existing);
        if (next.length >= recentGamesMax) break;
      }
      await _ui.put(_recentGamesKey, jsonEncode(next));
    } catch (e) {
      debugPrint('[HiveCache] pushRecentGameId failed: $e');
    }
  }

  static List<Map<String, dynamic>> resolveRecentGames(
    List<Map<String, dynamic>> catalog,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final g in catalog) {
      final id = g['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byId[id] = g;
    }
    final out = <Map<String, dynamic>>[];
    for (final id in loadRecentGameIds()) {
      final g = byId[id];
      if (g == null) continue;
      out.add(g);
      if (out.length >= recentGamesMax) break;
    }
    return out;
  }

  static String homeGamesRowFingerprint(List<Map<String, dynamic>> items) {
    final parts = items.map((g) {
      return [
        _str(g['id']),
        _str(g['slug']),
        _str(g['name']),
        _str(g['icon_url']),
        _str(g['game_url']),
        _str(g['sort_order']),
        _str(g['maintenance_mode']),
        _str(g['maintenance_message']),
        _str(g['webview_height_percent']),
        _configDataFingerprint(g['config_data']),
        _str(g['config_id']),
      ].join(':');
    }).toList()..sort();
    return parts.join('|');
  }

  static List<Map<String, dynamic>>? loadHomeGamesRow() {
    try {
      final raw = _ui.get(_homeGamesRowKey);
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadHomeGamesRow failed: $e');
      return null;
    }
  }

  static Future<bool> saveHomeGamesRow(List<Map<String, dynamic>> items) async {
    try {
      final normalized = items.map((g) {
        final cfg = _normalizeConfigData(g['config_data']);
        return {
          'id': g['id']?.toString() ?? '',
          'slug': g['slug']?.toString() ?? '',
          'name': g['name']?.toString() ?? '',
          'icon_url': g['icon_url']?.toString() ?? '',
          'game_url': g['game_url']?.toString() ?? '',
          'sort_order': g['sort_order'] ?? 0,
          'maintenance_mode': g['maintenance_mode'] ?? false,
          'maintenance_message': g['maintenance_message']?.toString() ?? '',
          'webview_height_percent': ?g['webview_height_percent'],
          if (cfg != null) 'config_data': cfg,
          if (g['config_id'] != null) 'config_id': g['config_id']?.toString(),
        };
      }).toList();
      final fp = homeGamesRowFingerprint(normalized);
      final existingFp = _ui.get(_homeGamesRowFpKey);
      if (existingFp != null && existingFp == fp) return false;
      await Future.wait([
        _ui.put(_homeGamesRowKey, jsonEncode(normalized)),
        _ui.put(_homeGamesRowFpKey, fp),
      ]);
      return true;
    } catch (e) {
      debugPrint('[HiveCache] saveHomeGamesRow failed: $e');
      return false;
    }
  }

  static String suGamesHubFingerprint(List<Map<String, dynamic>> categories) {
    final parts = categories.map((c) {
      final games =
          (c['games'] as List? ?? [])
              .whereType<Map>()
              .map(
                (g) => [
                  _str(g['id']),
                  _str(g['kind']),
                  _str(g['slug']),
                  _str(g['name']),
                  _str(g['icon_url']),
                  _str(g['game_url']),
                  _str(g['sort_order']),
                  _str(g['maintenance_mode']),
                  _str(g['maintenance_message']),
                  _str(g['webview_height_percent']),
                  _configDataFingerprint(g['config_data']),
                  _str(g['config_id']),
                ].join(':'),
              )
              .toList()
            ..sort();
      return [
        _str(c['id']),
        _str(c['name']),
        _str(c['sort_order']),
        games.join(','),
      ].join('#');
    }).toList()..sort();
    return parts.join('|');
  }

  static List<Map<String, dynamic>>? loadSuGamesHub() {
    try {
      final raw = _ui.get(_suGamesHubKey);
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadSuGamesHub failed: $e');
      return null;
    }
  }

  static Future<bool> saveSuGamesHub(
    List<Map<String, dynamic>> categories,
  ) async {
    try {
      final normalized = categories.map((c) {
        final games = (c['games'] as List? ?? []).whereType<Map>().map((g) {
          final cfg = _normalizeConfigData(g['config_data']);
          return {
            'id': g['id']?.toString() ?? '',
            'kind': g['kind']?.toString() ?? 'h5',
            'slug': g['slug']?.toString() ?? '',
            'name': g['name']?.toString() ?? '',
            'icon_url': g['icon_url']?.toString() ?? '',
            'game_url': g['game_url']?.toString() ?? '',
            'sort_order': g['sort_order'] ?? 0,
            'maintenance_mode': g['maintenance_mode'] ?? false,
            'maintenance_message': g['maintenance_message']?.toString() ?? '',
            'webview_height_percent': ?g['webview_height_percent'],
            if (cfg != null) 'config_data': cfg,
            if (g['config_id'] != null) 'config_id': g['config_id']?.toString(),
          };
        }).toList();
        return {
          'id': c['id']?.toString() ?? '',
          'name': c['name']?.toString() ?? '',
          'sort_order': c['sort_order'] ?? 0,
          'games': games,
        };
      }).toList();
      final fp = suGamesHubFingerprint(normalized);
      final existingFp = _ui.get(_suGamesHubFpKey);
      if (existingFp != null && existingFp == fp) return false;
      await Future.wait([
        _ui.put(_suGamesHubKey, jsonEncode(normalized)),
        _ui.put(_suGamesHubFpKey, fp),
      ]);
      return true;
    } catch (e) {
      debugPrint('[HiveCache] saveSuGamesHub failed: $e');
      return false;
    }
  }

  static const int coverLimit = 8;

  static List<Map<String, dynamic>>? loadRoomCovers() {
    try {
      final raw = _covers.get(_roomCoversKey);
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadRoomCovers failed: $e');
      return null;
    }
  }

  static Set<String> loadCachedRoomIds() {
    try {
      final raw = _covers.get(_roomCoversIdsKey);
      if (raw == null || raw.isEmpty) return {};
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> _roomCoverEntry(Map<String, dynamic> r) {
    final host = r['host'];
    final hostMap = host is Map ? Map<String, dynamic>.from(host) : null;
    return {
      'id': r['id']?.toString() ?? '',
      'image_url': r['image_url']?.toString() ?? '',
      'title': r['title']?.toString() ?? '',
      'online_users_count': r['online_users_count'] ?? 0,
      'seated_users_count': r['seated_users_count'] ?? 0,
      'host_name':
          r['host_name']?.toString() ?? hostMap?['username']?.toString() ?? '',
      'host_avatar':
          r['host_avatar']?.toString() ?? hostMap?['avatar_url']?.toString(),
      'room_topic': r['room_topic']?.toString(),
      'top_avatars': r['top_avatars'] is List ? r['top_avatars'] : [],
    };
  }

  static Future<void> saveRoomCovers(List<Map<String, dynamic>> rooms) async {
    try {
      final top = rooms.take(coverLimit).toList();
      final entries = top.map(_roomCoverEntry).toList();
      final ids = entries.map((e) => e['id']!).toList();
      await Future.wait([
        _covers.put(_roomCoversKey, jsonEncode(entries)),
        _covers.put(_roomCoversIdsKey, jsonEncode(ids)),
      ]);
    } catch (e) {
      debugPrint('[HiveCache] saveRoomCovers failed: $e');
    }
  }

  static bool hasNewRooms(List<Map<String, dynamic>> newRooms) {
    final cachedIds = loadCachedRoomIds();
    if (cachedIds.isEmpty) return true;
    for (final r in newRooms.take(coverLimit)) {
      final id = r['id']?.toString() ?? '';
      if (id.isNotEmpty && !cachedIds.contains(id)) return true;
    }
    return false;
  }

  static Map<String, dynamic>? loadEquipped(String userId) {
    if (userId.isEmpty) return null;
    try {
      final raw = _userMedia.get(_equipKey(userId));
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[HiveCache] loadEquipped failed: $e');
      return null;
    }
  }

  static Map<String, String?>? loadEquippedFrame(String userId) {
    final data = loadEquipped(userId);
    if (data == null) return null;
    final frame = data['frame'];
    if (frame == null) return <String, String?>{};
    if (frame is! Map) return <String, String?>{};
    final m = Map<String, dynamic>.from(frame);
    return {
      'image_url': m['image_url']?.toString(),
      'svga_url': m['svga_url']?.toString(),
    };
  }

  static ({String? carSvga, String? pattiUrl, String? pattiSvga})?
  loadEquippedEntrance(String userId) {
    final data = loadEquipped(userId);
    if (data == null) return null;
    final car = data['car'];
    final entrance = data['entrance'];
    final carMap = car is Map ? Map<String, dynamic>.from(car) : null;
    final entMap = entrance is Map ? Map<String, dynamic>.from(entrance) : null;
    return (
      carSvga: carMap?['svga_url']?.toString(),
      pattiUrl: entMap?['patti_url']?.toString(),
      pattiSvga: entMap?['patti_svga']?.toString(),
    );
  }

  static Future<void> saveEquipped(
    String userId,
    Map<String, dynamic> data,
  ) async {
    if (userId.isEmpty) return;
    await _withEquipLock(userId, () async {
      try {
        final next = Map<String, dynamic>.from(data);
        next['fingerprint'] = equipFingerprint(next);
        final existing = loadEquipped(userId);
        if (existing != null &&
            existing['fingerprint']?.toString() == next['fingerprint']) {
          return;
        }
        await _userMedia.put(_equipKey(userId), jsonEncode(next));
      } catch (e) {
        debugPrint('[HiveCache] saveEquipped failed: $e');
      }
    });
  }

  static Future<void> patchEquippedFrame(
    String userId,
    Map<String, String?>? frame,
  ) async {
    if (userId.isEmpty) return;
    await _withEquipLock(userId, () async {
      try {
        final current = loadEquipped(userId) ?? <String, dynamic>{};
        final next = Map<String, dynamic>.from(current);
        if (frame == null ||
            ((_str(frame['image_url']).isEmpty) &&
                (_str(frame['svga_url']).isEmpty))) {
          next['frame'] = null;
        } else {
          next['frame'] = {
            'image_url': frame['image_url'],
            'svga_url': frame['svga_url'],
          };
        }
        next['fingerprint'] = equipFingerprint(next);
        final existing = loadEquipped(userId);
        if (existing != null &&
            existing['fingerprint']?.toString() == next['fingerprint']) {
          return;
        }
        await _userMedia.put(_equipKey(userId), jsonEncode(next));
      } catch (e) {
        debugPrint('[HiveCache] patchEquippedFrame failed: $e');
      }
    });
  }

  static Future<void> patchEquippedEntrance(
    String userId, {
    String? carSvga,
    String? pattiUrl,
    String? pattiSvga,
  }) async {
    if (userId.isEmpty) return;
    await _withEquipLock(userId, () async {
      try {
        final current = loadEquipped(userId) ?? <String, dynamic>{};
        final next = Map<String, dynamic>.from(current);
        next['car'] = (carSvga == null || carSvga.isEmpty)
            ? null
            : {'svga_url': carSvga};
        if ((pattiUrl == null || pattiUrl.isEmpty) &&
            (pattiSvga == null || pattiSvga.isEmpty)) {
          next['entrance'] = null;
        } else {
          next['entrance'] = {'patti_url': pattiUrl, 'patti_svga': pattiSvga};
        }
        next['fingerprint'] = equipFingerprint(next);
        final existing = loadEquipped(userId);
        if (existing != null &&
            existing['fingerprint']?.toString() == next['fingerprint']) {
          return;
        }
        await _userMedia.put(_equipKey(userId), jsonEncode(next));
      } catch (e) {
        debugPrint('[HiveCache] patchEquippedEntrance failed: $e');
      }
    });
  }

  static Map<String, String?>? loadProfileMedia(String userId) {
    if (userId.isEmpty) return null;
    try {
      final raw = _userMedia.get(_profileKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return {
        'avatar_url': map['avatar_url']?.toString(),
        'banner_url': map['banner_url']?.toString(),
        'gender': map['gender']?.toString(),
        'country_code': map['country_code']?.toString(),
      };
    } catch (e) {
      debugPrint('[HiveCache] loadProfileMedia failed: $e');
      return null;
    }
  }

  static Future<void> saveProfileMedia(
    String userId, {
    String? avatarUrl,
    String? bannerUrl,
    String? gender,
    String? countryCode,
    bool clearAvatar = false,
    bool clearBanner = false,
  }) async {
    if (userId.isEmpty) return;
    try {
      final existing = loadProfileMedia(userId);
      final nextAvatar = clearAvatar
          ? null
          : (avatarUrl ?? existing?['avatar_url']);
      final nextBanner = clearBanner
          ? null
          : (bannerUrl ?? existing?['banner_url']);
      final nextGender = gender ?? existing?['gender'];
      final nextCountry = countryCode ?? existing?['country_code'];
      if (existing != null &&
          _str(existing['avatar_url']) == _str(nextAvatar) &&
          _str(existing['banner_url']) == _str(nextBanner) &&
          _str(existing['gender']) == _str(nextGender) &&
          _str(existing['country_code']) == _str(nextCountry)) {
        return;
      }
      await _userMedia.put(
        _profileKey(userId),
        jsonEncode({
          'avatar_url': nextAvatar,
          'banner_url': nextBanner,
          'gender': nextGender,
          'country_code': nextCountry,
        }),
      );
    } catch (e) {
      debugPrint('[HiveCache] saveProfileMedia failed: $e');
    }
  }

  static Future<void> clearUserMedia(String userId) async {
    if (userId.isEmpty) return;
    try {
      await Future.wait([
        _userMedia.delete(_equipKey(userId)),
        _userMedia.delete(_profileKey(userId)),
        _userMedia.delete(_backpackKey(userId)),
        _userMedia.delete(_backpackFpKey(userId)),
        _userMedia.delete(_badgesKey(userId)),
        _userMedia.delete(_badgesFpKey(userId)),
      ]);
    } catch (e) {
      debugPrint('[HiveCache] clearUserMedia failed: $e');
    }
  }

  static String badgesFingerprint(List<Map<String, dynamic>> badges) {
    final parts = badges.map((b) {
      return [
        _str(b['type']),
        _str(b['level']),
        _str(b['imageUrl'] ?? b['image_url']),
        _str(b['name']),
        _str(b['priority']),
      ].join(':');
    }).toList()..sort();
    return parts.join('|');
  }

  static List<Map<String, dynamic>>? loadBadges(String userId) {
    if (userId.isEmpty) return null;
    try {
      final raw = _userMedia.get(_badgesKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadBadges failed: $e');
      return null;
    }
  }

  static String? loadBadgesFingerprint(String userId) {
    if (userId.isEmpty) return null;
    try {
      return _userMedia.get(_badgesFpKey(userId));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveBadges(
    String userId,
    List<Map<String, dynamic>> badges,
  ) async {
    if (userId.isEmpty) return false;
    try {
      final fp = badgesFingerprint(badges);
      final existingFp = loadBadgesFingerprint(userId);
      if (existingFp != null && existingFp == fp) return false;
      await Future.wait([
        _userMedia.put(_badgesKey(userId), jsonEncode(badges)),
        _userMedia.put(_badgesFpKey(userId), fp),
      ]);
      return true;
    } catch (e) {
      debugPrint('[HiveCache] saveBadges failed: $e');
      return false;
    }
  }

  static String backpackFingerprint(List<Map<String, dynamic>> items) {
    final parts = items.map((item) {
      final si = item['shop_items'];
      final shop = si is Map ? Map<String, dynamic>.from(si) : null;
      return [
        _str(item['id']),
        _str(item['item_id']),
        _str(item['is_equipped']),
        _str(item['expires_at']),
        _str(shop?['image_url']),
        _str(shop?['svga_url']),
        _str(shop?['name']),
        _str(
          shop?['shop_categories'] is Map
              ? (shop!['shop_categories'] as Map)['name']
              : null,
        ),
      ].join(':');
    }).toList()..sort();
    return parts.join('|');
  }

  static List<Map<String, dynamic>>? loadBackpack(String userId) {
    if (userId.isEmpty) return null;
    try {
      final raw = _userMedia.get(_backpackKey(userId));
      if (raw == null || raw.isEmpty) return null;
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      debugPrint('[HiveCache] loadBackpack failed: $e');
      return null;
    }
  }

  static String? loadBackpackFingerprint(String userId) {
    if (userId.isEmpty) return null;
    try {
      return _userMedia.get(_backpackFpKey(userId));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveBackpack(
    String userId,
    List<Map<String, dynamic>> items,
  ) async {
    if (userId.isEmpty) return false;
    try {
      final fp = backpackFingerprint(items);
      final existingFp = loadBackpackFingerprint(userId);
      if (existingFp != null && existingFp == fp) return false;
      await Future.wait([
        _userMedia.put(_backpackKey(userId), jsonEncode(items)),
        _userMedia.put(_backpackFpKey(userId), fp),
      ]);
      return true;
    } catch (e) {
      debugPrint('[HiveCache] saveBackpack failed: $e');
      return false;
    }
  }

  static Future<Box<String>> _rankFrames() async {
    if (_rankFramesBox != null) return _rankFramesBox!;
    _rankFramesBox = await _openBox(_rankFramesBoxName);
    return _rankFramesBox!;
  }

  static Future<Map<String, dynamic>?> loadRankFrames() async {
    try {
      final box = await _rankFrames();
      final raw = box.get(_rankFramesKey);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[HiveCache] loadRankFrames failed: $e');
      return null;
    }
  }

  static Future<void> saveRankFrames(Map<String, dynamic> data) async {
    try {
      final box = await _rankFrames();
      await box.put(_rankFramesKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[HiveCache] saveRankFrames failed: $e');
    }
  }
}
