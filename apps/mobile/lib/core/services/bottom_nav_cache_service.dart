import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';

class BottomNavCacheService {
  BottomNavCacheService._();

  static const _configKey = 'bottom_nav_config_cache_v1';
  static const _versionKey = 'bottom_nav_config_version_v1';

  static Future<List<BottomNavItemModel>?> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configKey);
      if (raw == null || raw.isEmpty) return null;

      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map(
            (e) =>
                BottomNavItemModel.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (items.isEmpty) return null;
      return BottomNavItemModel.mergeWithDefaults(items);
    } catch (e) {
      debugPrint('[BottomNavCache] load failed: $e');
      return null;
    }
  }

  static Future<void> saveCached(List<BottomNavItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items.map((e) => e.toJson()).toList();
      await prefs.setString(_configKey, jsonEncode(payload));
      await prefs.setString(_versionKey, computeVersionHash(items));
    } catch (e) {
      debugPrint('[BottomNavCache] save failed: $e');
    }
  }

  static Future<String?> loadCachedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey);
  }

  static String computeVersionHash(List<BottomNavItemModel> items) {
    return items
        .map(
          (e) =>
              '${e.navKey}:${e.updatedAt?.toIso8601String() ?? ''}:${e.iconUrl}:${e.activeIconUrl ?? ''}:${e.focusOverlayUrl ?? ''}:${e.label}',
        )
        .join('|');
  }

  static bool hasChanged(
    List<BottomNavItemModel>? cached,
    List<BottomNavItemModel> remote,
  ) {
    if (cached == null || cached.isEmpty) return true;
    return computeVersionHash(cached) != computeVersionHash(remote);
  }
}
