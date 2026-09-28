import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/providers/party_screen_config_provider.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';

class PartyScreenCacheService {
  PartyScreenCacheService._();

  static const _prefsKey = 'party_screen_config_cache_v1';

  static Future<PartyScreenConfig?> loadCached() async {
    try {
      final hiveMap = HiveCacheService.loadPartyConfig();
      if (hiveMap != null) {
        return PartyScreenConfig.fromMap(hiveMap);
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      await HiveCacheService.savePartyConfig(map);
      await prefs.remove(_prefsKey);
      return PartyScreenConfig.fromMap(map);
    } catch (e) {
      debugPrint('[PartyScreenCache] load failed: $e');
      return null;
    }
  }

  static Future<void> saveCached(PartyScreenConfig config) async {
    try {
      await HiveCacheService.savePartyConfig(config.toJson());
    } catch (e) {
      debugPrint('[PartyScreenCache] save failed: $e');
    }
  }

  static String computeVersionHash(PartyScreenConfig config) {
    return '${config.topImageUrl}|${config.bottomImageUrl}|${config.updatedAt?.toIso8601String() ?? ''}';
  }

  static bool hasChanged(PartyScreenConfig? cached, PartyScreenConfig remote) {
    if (cached == null) return true;
    return computeVersionHash(cached) != computeVersionHash(remote);
  }
}
