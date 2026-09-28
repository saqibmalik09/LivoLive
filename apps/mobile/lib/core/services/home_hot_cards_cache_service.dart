import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/providers/home_hot_cards_config_provider.dart';

class HomeHotCardsCacheService {
  HomeHotCardsCacheService._();

  static const _configKey = 'home_hot_cards_config_cache_v1';

  static Future<HomeHotCardsConfig?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configKey);
      if (raw == null || raw.isEmpty) return null;
      return HomeHotCardsConfig.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e) {
      debugPrint('[HomeHotCardsCache] load failed: $e');
      return null;
    }
  }

  static Future<void> saveCached(HomeHotCardsConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(config.toJson()));
    } catch (e) {
      debugPrint('[HomeHotCardsCache] save failed: $e');
    }
  }

  static String computeVersionHash(HomeHotCardsConfig config) {
    return config.cacheVersion;
  }

  static bool hasChanged(
    HomeHotCardsConfig? cached,
    HomeHotCardsConfig remote,
  ) {
    if (cached == null) return true;
    return computeVersionHash(cached) != computeVersionHash(remote);
  }
}
