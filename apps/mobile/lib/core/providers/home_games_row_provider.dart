import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/game_audience_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeGameIconItem {
  const HomeGameIconItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.iconUrl,
    required this.gameUrl,
    required this.sortOrder,
    required this.maintenanceMode,
    this.maintenanceMessage,
    this.configData,
    this.configId,
    this.heightPercent,
  });

  final String id;
  final String slug;
  final String name;
  final String iconUrl;
  final String gameUrl;
  final int sortOrder;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final Map<String, dynamic>? configData;

  final String? configId;

  final double? heightPercent;

  Map<String, dynamic> toLaunchMap() => {
    'slug': slug,
    'name': name,
    'icon_url': iconUrl,
    'game_url': gameUrl,
    'maintenance_mode': maintenanceMode,
    'maintenance_message': maintenanceMessage,
    if (configData != null) 'config_data': configData,
  };

  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'icon_url': iconUrl,
    'game_url': gameUrl,
    'sort_order': sortOrder,
    'maintenance_mode': maintenanceMode,
    'maintenance_message': maintenanceMessage,
    if (configData != null) 'config_data': configData,
    if (configId != null) 'config_id': configId,
    if (heightPercent != null) 'webview_height_percent': heightPercent,
  };

  factory HomeGameIconItem.fromCacheMap(Map<String, dynamic> m) {
    final rawCfg = m['config_data'];
    return HomeGameIconItem(
      id: m['id']?.toString() ?? '',
      slug: m['slug']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      iconUrl: m['icon_url']?.toString() ?? '',
      gameUrl: m['game_url']?.toString() ?? '',
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      maintenanceMode: m['maintenance_mode'] == true,
      maintenanceMessage: m['maintenance_message']?.toString(),
      configData: rawCfg is Map ? Map<String, dynamic>.from(rawCfg) : null,
      configId: m['config_id']?.toString(),
      heightPercent: (m['webview_height_percent'] as num?)?.toDouble(),
    );
  }
}

Future<List<HomeGameIconItem>> _fetchHomeGamesRowRemote() async {
  final client = Supabase.instance.client;

  final rowRes = await client
      .from('home_games_row_items')
      .select('id, game_slug, title, image_url, sort_order')
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  final rows = (rowRes as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return const [];

  final slugs = rows
      .map((r) => r['game_slug']?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  final gamesRes = await client
      .from('game_configs')
      .select(
        'id, slug, name, icon_url, game_url, is_active, maintenance_mode, maintenance_message, webview_height_percent, config_data',
      )
      .inFilter('slug', slugs);

  final bySlug = <String, Map<String, dynamic>>{};
  for (final g in (gamesRes as List).cast<Map<String, dynamic>>()) {
    final slug = g['slug']?.toString() ?? '';
    if (slug.isEmpty) continue;
    bySlug[slug] = g;
  }

  final out = <HomeGameIconItem>[];
  for (final r in rows) {
    final slug = r['game_slug']?.toString() ?? '';
    final game = bySlug[slug];
    if (game == null) continue;
    if (game['is_active'] == false) continue;

    final titleOverride = r['title']?.toString().trim() ?? '';
    final imageOverride = r['image_url']?.toString().trim() ?? '';
    final name = titleOverride.isNotEmpty
        ? titleOverride
        : (game['name']?.toString() ?? slug);
    final icon = imageOverride.isNotEmpty
        ? imageOverride
        : (game['icon_url']?.toString() ?? '');
    final url = game['game_url']?.toString() ?? '';
    if (url.isEmpty) continue;

    final rawCfg = game['config_data'];
    out.add(
      HomeGameIconItem(
        id: r['id']?.toString() ?? slug,
        slug: slug,
        name: name,
        iconUrl: icon,
        gameUrl: url,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
        maintenanceMode: game['maintenance_mode'] == true,
        maintenanceMessage: game['maintenance_message']?.toString(),
        configData: rawCfg is Map ? Map<String, dynamic>.from(rawCfg) : null,
        configId: game['id']?.toString(),
        heightPercent: (game['webview_height_percent'] as num?)?.toDouble(),
      ),
    );
  }
  return out;
}

Future<List<HomeGameIconItem>> _withAudience(
  List<HomeGameIconItem> items,
) async {
  return filterAudienceItems<HomeGameIconItem>(
    items: items,
    idOf: (g) => g.configId ?? g.id,
    configDataOf: (g) => g.configData,
  );
}

final homeGamesRowProvider = FutureProvider.autoDispose<List<HomeGameIconItem>>(
  (ref) async {
    ref.keepAlive();

    final cachedMaps = HiveCacheService.loadHomeGamesRow();
    if (cachedMaps != null && cachedMaps.isNotEmpty) {
      final cached = await _withAudience(
        cachedMaps.map(HomeGameIconItem.fromCacheMap).toList(),
      );
      Future(() async {
        try {
          final remote = await _fetchHomeGamesRowRemote();
          final changed = await HiveCacheService.saveHomeGamesRow(
            remote.map((e) => e.toCacheMap()).toList(),
          );
          if (changed) {
            ref.invalidateSelf();
          }
        } catch (e) {
          debugPrint('[homeGamesRowProvider] bg refresh failed: $e');
        }
      });
      return cached;
    }

    try {
      final remote = await _fetchHomeGamesRowRemote();
      await HiveCacheService.saveHomeGamesRow(
        remote.map((e) => e.toCacheMap()).toList(),
      );
      return _withAudience(remote);
    } catch (e) {
      debugPrint('[homeGamesRowProvider] fetch failed: $e');
      return const [];
    }
  },
);
