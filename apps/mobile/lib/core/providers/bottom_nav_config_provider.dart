import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/services/bottom_nav_cache_service.dart';

class BottomNavItemModel {
  const BottomNavItemModel({
    required this.navKey,
    required this.label,
    required this.iconUrl,
    this.activeIconUrl,
    this.focusOverlayUrl,
    required this.sortOrder,
    required this.isActive,
    this.updatedAt,
  });

  final String navKey;
  final String label;
  final String iconUrl;
  final String? activeIconUrl;
  final String? focusOverlayUrl;
  final int sortOrder;
  final bool isActive;
  final DateTime? updatedAt;

  String get fallbackAsset =>
      _fallbackAssets[navKey] ?? 'assets/nav/nav_my.webp';

  String get cacheVersion =>
      updatedAt?.millisecondsSinceEpoch.toString() ??
      iconUrl.hashCode.toString();

  String versionedUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['v'] = cacheVersion;
    return uri.replace(queryParameters: params).toString();
  }

  String get versionedIconUrl => versionedUrl(iconUrl);
  String? get versionedActiveIconUrl =>
      activeIconUrl != null && activeIconUrl!.isNotEmpty
      ? versionedUrl(activeIconUrl!)
      : null;
  String? get versionedFocusOverlayUrl =>
      focusOverlayUrl != null && focusOverlayUrl!.isNotEmpty
      ? versionedUrl(focusOverlayUrl!)
      : null;

  static const _fallbackAssets = {
    'home': 'assets/nav/nav_home.webp',
    'party': 'assets/nav/nav_party.webp',
    'game': 'assets/nav/nav_game.webp',
    'message': 'assets/nav/nav_message.webp',
    'my': 'assets/nav/nav_my.webp',
  };

  static const _fallbackLabels = {
    'home': 'Home',
    'party': 'Party',
    'game': 'Game',
    'message': 'Message',
    'my': 'My',
  };

  static const defaultOrder = ['home', 'party', 'game', 'message', 'my'];

  factory BottomNavItemModel.fromMap(Map<String, dynamic> map) {
    DateTime? updatedAt;
    final rawUpdated = map['updated_at'];
    if (rawUpdated is String && rawUpdated.isNotEmpty) {
      updatedAt = DateTime.tryParse(rawUpdated);
    }

    return BottomNavItemModel(
      navKey: map['nav_key'] as String,
      label:
          map['label'] as String? ?? _fallbackLabels[map['nav_key']] ?? 'Tab',
      iconUrl: (map['icon_url'] as String?)?.trim() ?? '',
      activeIconUrl: (map['active_icon_url'] as String?)?.trim(),
      focusOverlayUrl: (map['focus_overlay_url'] as String?)?.trim(),
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'nav_key': navKey,
    'label': label,
    'icon_url': iconUrl,
    'active_icon_url': activeIconUrl,
    'focus_overlay_url': focusOverlayUrl,
    'sort_order': sortOrder,
    'is_active': isActive,
    'updated_at': updatedAt?.toIso8601String(),
  };

  static List<BottomNavItemModel> defaults() {
    return List.generate(defaultOrder.length, (index) {
      final key = defaultOrder[index];
      return BottomNavItemModel(
        navKey: key,
        label: _fallbackLabels[key]!,
        iconUrl: '',
        sortOrder: index,
        isActive: true,
      );
    });
  }

  static List<BottomNavItemModel> mergeWithDefaults(
    List<BottomNavItemModel> remote,
  ) {
    final byKey = {for (final item in remote) item.navKey: item};
    return defaultOrder.asMap().entries.map((entry) {
      final key = entry.value;
      final remoteItem = byKey[key];
      if (remoteItem != null && remoteItem.isActive) {
        return remoteItem;
      }
      return BottomNavItemModel(
        navKey: key,
        label: remoteItem?.label ?? _fallbackLabels[key]!,
        iconUrl: remoteItem?.iconUrl ?? '',
        activeIconUrl: remoteItem?.activeIconUrl,
        focusOverlayUrl: remoteItem?.focusOverlayUrl,
        sortOrder: entry.key,
        isActive: true,
        updatedAt: remoteItem?.updatedAt,
      );
    }).toList();
  }
}

class BottomNavConfigNotifier extends AsyncNotifier<List<BottomNavItemModel>> {
  bool _refreshScheduled = false;

  @override
  Future<List<BottomNavItemModel>> build() async {
    ref.keepAlive();

    final cached = await BottomNavCacheService.loadCached();
    if (cached != null && cached.isNotEmpty) {
      _scheduleSilentRefresh();
      return cached;
    }

    final remote = await _fetchRemote();
    await _persistAndPrefetch(remote);
    return remote;
  }

  Future<void> checkForUpdatesSilently() async {
    try {
      final cached =
          state.valueOrNull ?? await BottomNavCacheService.loadCached();
      final remote = await _fetchRemote();
      if (!BottomNavCacheService.hasChanged(cached, remote)) return;
      await _persistAndPrefetch(remote);
      state = AsyncData(remote);
    } catch (e) {
      debugPrint('[BottomNav] silent check failed: $e');
    }
  }

  void _scheduleSilentRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    unawaited(
      Future<void>(() async {
        try {
          final cached = await BottomNavCacheService.loadCached();
          final remote = await _fetchRemote();
          if (!BottomNavCacheService.hasChanged(cached, remote)) return;

          await _persistAndPrefetch(remote);
          state = AsyncData(remote);
        } catch (e) {
          debugPrint('[BottomNav] silent refresh failed: $e');
        }
      }),
    );
  }

  Future<List<BottomNavItemModel>> _fetchRemote() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('bottom_nav_items')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final remote = List<Map<String, dynamic>>.from(
        response,
      ).map(BottomNavItemModel.fromMap).toList();

      if (remote.isEmpty) return BottomNavItemModel.defaults();
      return BottomNavItemModel.mergeWithDefaults(remote);
    } catch (e) {
      debugPrint('[BottomNav] fetch failed: $e');
      final cached = await BottomNavCacheService.loadCached();
      return cached ?? BottomNavItemModel.defaults();
    }
  }

  Future<void> _persistAndPrefetch(List<BottomNavItemModel> items) async {
    await BottomNavCacheService.saveCached(items);
  }
}

final bottomNavConfigProvider =
    AsyncNotifierProvider<BottomNavConfigNotifier, List<BottomNavItemModel>>(
      BottomNavConfigNotifier.new,
    );

class BottomNavIconPrefetch {
  static final Set<String> _prefetched = {};

  static Future<void> prefetchAll(
    BuildContext context,
    List<BottomNavItemModel> items,
  ) async {
    for (final item in items) {
      await _prefetchUrl(context, item.versionedIconUrl);
      await _prefetchUrl(context, item.versionedActiveIconUrl);
      await _prefetchUrl(context, item.versionedFocusOverlayUrl);
    }
  }

  static Future<void> _prefetchUrl(BuildContext context, String? url) async {
    if (url == null || url.isEmpty || _prefetched.contains(url)) return;
    _prefetched.add(url);
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (_) {}
  }
}

int bottomNavIndexForKey(String navKey) {
  final index = BottomNavItemModel.defaultOrder.indexOf(navKey);
  return index >= 0 ? index : 0;
}

bool isHomeNavKey(String navKey) => navKey == 'home';
