import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/baishun_game.dart';
import 'package:sk_live/core/util/game_audience_filter.dart';
import 'package:sk_live/core/util/wave_game.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuGameItem {
  const SuGameItem({
    required this.id,
    required this.kind,
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
  final String kind;
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

  bool get isRupee => kind == 'rupee';

  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'kind': kind,
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

  factory SuGameItem.fromCacheMap(Map<String, dynamic> m) {
    final rawCfg = m['config_data'];
    return SuGameItem(
      id: m['id']?.toString() ?? '',
      kind: m['kind']?.toString() ?? 'h5',
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

class SuGameCategory {
  const SuGameCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.games,
  });

  final String id;
  final String name;
  final int sortOrder;
  final List<SuGameItem> games;

  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'name': name,
    'sort_order': sortOrder,
    'games': games.map((g) => g.toCacheMap()).toList(),
  };

  factory SuGameCategory.fromCacheMap(Map<String, dynamic> m) {
    final rawGames = (m['games'] as List? ?? [])
        .whereType<Map>()
        .map((e) => SuGameItem.fromCacheMap(Map<String, dynamic>.from(e)))
        .toList();
    return SuGameCategory(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      games: rawGames,
    );
  }
}

SuGameItem? _waveHubItem(Map<String, dynamic> card, int sortOrder) {
  final id = card['game_id'] ?? card['id'];
  final play = card['play_url']?.toString() ?? '';
  if (id == null || play.isEmpty) return null;
  final slug = card['route_slug']?.toString().trim() ?? '';
  return SuGameItem(
    id: 'wave-$id',
    kind: 'h5',
    slug: slug.isNotEmpty ? slug : 'wave-$id',
    name: card['name']?.toString() ?? 'Game',
    iconUrl: card['listing_image']?.toString() ?? '',
    gameUrl: play,
    sortOrder: sortOrder,
    maintenanceMode: false,
    configData: {'provider': 'wave', 'game_id': id},
    configId: 'wave-$id',
    heightPercent: (card['sheet_height_percent'] as num?)?.toDouble() ?? 100,
  );
}

Future<List<SuGameCategory>> _fetchSuGamesHubRemote() async {
  final waveFuture = fetchWaveCatalog();
  final client = Supabase.instance.client;

  final catRes = await client
      .from('su_game_categories')
      .select('id, name, sort_order')
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  final categories = (catRes as List).cast<Map<String, dynamic>>();
  if (categories.isEmpty) return _appendWaveCategory(const [], waveFuture);

  final catIds = categories
      .map((c) => c['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toList();

  final itemRes = await client
      .from('su_game_items')
      .select('id, category_id, kind, game_slug, title, image_url, sort_order')
      .eq('is_active', true)
      .inFilter('category_id', catIds)
      .order('sort_order', ascending: false);

  final items = (itemRes as List).cast<Map<String, dynamic>>();
  final h5Slugs = items
      .where((i) => (i['kind']?.toString() ?? 'h5') == 'h5')
      .map((i) => i['game_slug']?.toString().trim() ?? '')
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  final bySlug = <String, Map<String, dynamic>>{};
  if (h5Slugs.isNotEmpty) {
    final gamesRes = await client
        .from('game_configs')
        .select(
          'id, slug, name, icon_url, game_url, is_active, maintenance_mode, maintenance_message, webview_height_percent, config_data, test_game_url, test_user_ids',
        )
        .inFilter('slug', h5Slugs);
    for (final g in (gamesRes as List).cast<Map<String, dynamic>>()) {
      final slug = g['slug']?.toString() ?? '';
      if (slug.isEmpty) continue;
      bySlug[slug] = g;
    }
  }

  final gamesByCat = <String, List<SuGameItem>>{};
  for (final row in items) {
    final catId = row['category_id']?.toString() ?? '';
    if (catId.isEmpty) continue;
    final kind = row['kind']?.toString() == 'rupee' ? 'rupee' : 'h5';
    if (kind == 'rupee') {
      final titleOverride = row['title']?.toString().trim() ?? '';
      (gamesByCat[catId] ??= []).add(
        SuGameItem(
          id: row['id']?.toString() ?? 'rupee',
          kind: 'rupee',
          slug: 'rupee_game',
          name: titleOverride.isNotEmpty ? titleOverride : 'Lucky Offer',
          iconUrl: row['image_url']?.toString() ?? '',
          gameUrl: '',
          sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
          maintenanceMode: false,
        ),
      );
      continue;
    }

    final slug = row['game_slug']?.toString() ?? '';
    final game = bySlug[slug];
    if (game == null) continue;
    if (game['is_active'] == false) continue;
    final rawCfg = game['config_data'];
    final cfgMap = rawCfg is Map ? Map<String, dynamic>.from(rawCfg) : null;
    final url = resolveBaishunGameUrl({
      'game_url': game['game_url'],
      'config_data': cfgMap,
      'test_game_url': game['test_game_url'],
      'test_user_ids': game['test_user_ids'],
    }, fallbackUrl: game['game_url']?.toString());
    if (url.isEmpty) continue;

    final titleOverride = row['title']?.toString().trim() ?? '';
    final imageOverride = row['image_url']?.toString().trim() ?? '';
    (gamesByCat[catId] ??= []).add(
      SuGameItem(
        id: row['id']?.toString() ?? slug,
        kind: 'h5',
        slug: slug,
        name: titleOverride.isNotEmpty
            ? titleOverride
            : (game['name']?.toString() ?? slug),
        iconUrl: imageOverride.isNotEmpty
            ? imageOverride
            : (game['icon_url']?.toString() ?? ''),
        gameUrl: url,
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        maintenanceMode: game['maintenance_mode'] == true,
        maintenanceMessage: game['maintenance_message']?.toString(),
        configData: cfgMap,
        configId: game['id']?.toString(),
        heightPercent: (game['webview_height_percent'] as num?)?.toDouble(),
      ),
    );
  }

  final out = <SuGameCategory>[];
  for (final c in categories) {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    out.add(
      SuGameCategory(
        id: id,
        name: c['name']?.toString() ?? '',
        sortOrder: (c['sort_order'] as num?)?.toInt() ?? 0,
        games: gamesByCat[id] ?? const [],
      ),
    );
  }

  return _appendWaveCategory(out, waveFuture);
}

Future<List<SuGameCategory>> _appendWaveCategory(
  List<SuGameCategory> categories,
  Future<Map<String, dynamic>?> waveFuture,
) async {
  final waveCards = waveFullCards(await waveFuture);
  final waveGames = <SuGameItem>[];
  for (var i = 0; i < waveCards.length; i++) {
    final item = _waveHubItem(waveCards[i], 1000 - i);
    if (item != null) waveGames.add(item);
  }
  if (waveGames.isEmpty) return categories;
  return [
    ...categories,
    SuGameCategory(
      id: 'wave',
      name: 'Wave Games',
      sortOrder: 900,
      games: waveGames,
    ),
  ];
}

Future<List<SuGameCategory>> _withAudience(
  List<SuGameCategory> categories,
) async {
  final out = <SuGameCategory>[];
  for (final cat in categories) {
    final kept = await filterAudienceItems<SuGameItem>(
      items: cat.games,
      idOf: (g) => g.isRupee ? g.id : (g.configId ?? g.id),
      configDataOf: (g) => g.configData,
    );
    out.add(
      SuGameCategory(
        id: cat.id,
        name: cat.name,
        sortOrder: cat.sortOrder,
        games: kept,
      ),
    );
  }
  return out;
}

final suGamesHubProvider = FutureProvider.autoDispose<List<SuGameCategory>>((
  ref,
) async {
  ref.keepAlive();

  final cachedMaps = HiveCacheService.loadSuGamesHub();
  if (cachedMaps != null && cachedMaps.isNotEmpty) {
    final cached = await _withAudience(
      cachedMaps.map(SuGameCategory.fromCacheMap).toList(),
    );
    Future(() async {
      try {
        final remote = await _fetchSuGamesHubRemote();
        final changed = await HiveCacheService.saveSuGamesHub(
          remote.map((e) => e.toCacheMap()).toList(),
        );
        if (changed) ref.invalidateSelf();
      } catch (e) {
        debugPrint('[suGamesHubProvider] bg refresh failed: $e');
      }
    });
    return cached;
  }

  try {
    final remote = await _fetchSuGamesHubRemote();
    await HiveCacheService.saveSuGamesHub(
      remote.map((e) => e.toCacheMap()).toList(),
    );
    return _withAudience(remote);
  } catch (e) {
    debugPrint('[suGamesHubProvider] fetch failed: $e');
    return const [];
  }
});
