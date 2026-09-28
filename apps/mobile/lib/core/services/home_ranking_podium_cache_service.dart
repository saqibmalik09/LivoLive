import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/providers/home_ranking_podium_config_provider.dart';

class HomeRankingPodiumCacheService {
  HomeRankingPodiumCacheService._();

  static const _configKey = 'home_ranking_podium_config_cache_v1';

  static Future<HomeRankingPodiumConfig?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configKey);
      if (raw == null || raw.isEmpty) return null;
      return HomeRankingPodiumConfig.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e) {
      debugPrint('[RankingPodiumCache] load failed: $e');
      return null;
    }
  }

  static Future<void> saveCached(HomeRankingPodiumConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(config.toJson()));
    } catch (e) {
      debugPrint('[RankingPodiumCache] save failed: $e');
    }
  }

  static bool hasChanged(
    HomeRankingPodiumConfig? cached,
    HomeRankingPodiumConfig remote,
  ) {
    if (cached == null) return true;
    return cached.cacheVersion != remote.cacheVersion;
  }
}
