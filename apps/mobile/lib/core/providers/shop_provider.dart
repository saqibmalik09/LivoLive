import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/app_image_cache.dart';
import 'package:sk_live/core/util/gift_video_cache.dart';
import 'package:sk_live/core/util/gift_show_duration.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/util/svga_cache.dart';

final supabase = Supabase.instance.client;

class ShopCategory {
  final String id;
  final String name;
  final String? iconUrl;
  final int displayOrder;

  ShopCategory({
    required this.id,
    required this.name,
    this.iconUrl,
    this.displayOrder = 0,
  });

  factory ShopCategory.fromMap(Map<String, dynamic> map) {
    return ShopCategory(
      id: map['id'],
      name: map['name'],
      iconUrl: map['icon_url'],
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShopItem {
  final String id;
  final String categoryId;
  final String name;
  final int priceCoins;
  final int durationDays;
  final String? imageUrl;
  final String? svgaUrl;
  final String? soundUrl;
  final bool isForSale;
  final String sourceType;
  final int requiredVipLevel;
  final int requiredWealthValue;
  final int requiredCharmValue;
  final String? categoryName;
  final bool isGift;
  final bool isFullScreen;

  /// Centre hold on send; null when the row predates the column.
  final int? showDurationMs;

  ShopItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceCoins,
    required this.durationDays,
    required this.isForSale,
    this.sourceType = 'shop',
    this.requiredVipLevel = 0,
    this.requiredWealthValue = 0,
    this.requiredCharmValue = 0,
    this.imageUrl,
    this.svgaUrl,
    this.soundUrl,
    this.categoryName,
    this.isGift = false,
    this.isFullScreen = false,
    this.showDurationMs,
  }) {
    if (isGift && showDurationMs != null) {
      GiftShowDuration.remember(
        svgaUrl: svgaUrl,
        iconUrl: imageUrl,
        ms: showDurationMs,
      );
    }
  }

  factory ShopItem.fromMap(Map<String, dynamic> map) {
    int level = map['required_vip_level'] ?? 0;
    final name = map['name'] ?? '';
    if (level == 0 && name.toString().startsWith('VIP')) {
      final match = RegExp(r'VIP\s*(\d+)').firstMatch(name);
      if (match != null) {
        level = int.parse(match.group(1)!);
      }
    }

    final showMs = (map['show_duration_ms'] as num?)?.toInt();
    if (showMs != null) {
      // The gateway echoes the raw column values, not the normalized URLs.
      GiftShowDuration.remember(
        svgaUrl: map['svga_url']?.toString(),
        iconUrl: map['image_url']?.toString(),
        ms: showMs,
      );
    }

    return ShopItem(
      id: map['id'],
      categoryId: map['category_id'],
      name: name,
      priceCoins: map['price_coins'] ?? 0,
      durationDays: map['duration_days'] ?? 0,
      isForSale: map['is_for_sale'] ?? true,
      sourceType: map['source_type'] ?? 'shop',
      requiredVipLevel: level,
      requiredWealthValue: (map['required_wealth_value'] as num?)?.toInt() ?? 0,
      requiredCharmValue: (map['required_charm_value'] as num?)?.toInt() ?? 0,
      imageUrl: MediaUrlUtil.nullableMediaUrl(map['image_url'] as String?),
      svgaUrl: MediaUrlUtil.nullableMediaUrl(map['svga_url'] as String?),
      soundUrl: MediaUrlUtil.nullableMediaUrl(map['sound_url'] as String?),
      categoryName: map['shop_categories']?['name'] ?? map['category_name'],
      isGift: map['is_gift'] ?? false,
      isFullScreen: map['is_full_screen'] ?? false,
      showDurationMs: showMs,
    );
  }

  Map<String, dynamic> toCacheMap({
    required String categoryName,
    required int categoryOrder,
    String? categoryIcon,
  }) {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'price_coins': priceCoins,
      'image_url': imageUrl ?? '',
      'svga_url': svgaUrl ?? '',
      'is_full_screen': isFullScreen,
      if (showDurationMs != null) 'show_duration_ms': showDurationMs,
      'category_name': categoryName,
      'category_order': categoryOrder,
      'category_icon': categoryIcon ?? '',
    };
  }

  factory ShopItem.fromCacheMap(Map<String, dynamic> map) {
    return ShopItem(
      id: map['id']?.toString() ?? '',
      categoryId: map['category_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      priceCoins: (map['price_coins'] as num?)?.toInt() ?? 0,
      durationDays: 0,
      isForSale: true,
      imageUrl: MediaUrlUtil.nullableMediaUrl(map['image_url']?.toString()),
      svgaUrl: MediaUrlUtil.nullableMediaUrl(map['svga_url']?.toString()),
      categoryName: map['category_name']?.toString(),
      isGift: true,
      isFullScreen: map['is_full_screen'] == true,
      showDurationMs: (map['show_duration_ms'] as num?)?.toInt(),
    );
  }
}

/// One network load for the whole gift sheet. Categories and per-tab lists are
/// derived from this; the sheet used to wait on one request per category after
/// another full download just to list the tabs.
class GiftCatalog {
  const GiftCatalog({
    required this.categories,
    required this.giftsByCategory,
    required this.allItems,
  });

  final List<ShopCategory> categories;
  final Map<String, List<ShopItem>> giftsByCategory;
  final List<ShopItem> allItems;

  bool get isEmpty => categories.isEmpty || allItems.isEmpty;
}

GiftCatalog _catalogFromItems(
  List<ShopItem> items, {
  Map<String, ShopCategory>? categoryMeta,
}) {
  final byCategory = <String, List<ShopItem>>{};
  final categories = <String, ShopCategory>{};

  for (final item in items) {
    if (item.categoryId.isEmpty) continue;
    (byCategory[item.categoryId] ??= []).add(item);
    categories.putIfAbsent(item.categoryId, () {
      final meta = categoryMeta?[item.categoryId];
      return ShopCategory(
        id: item.categoryId,
        name: meta?.name ?? item.categoryName ?? 'Gifts',
        iconUrl: meta?.iconUrl,
        displayOrder: meta?.displayOrder ?? 0,
      );
    });
  }

  for (final list in byCategory.values) {
    list.sort((a, b) => a.priceCoins.compareTo(b.priceCoins));
  }

  final ordered = categories.values.toList()
    ..sort((a, b) {
      final byOrder = a.displayOrder.compareTo(b.displayOrder);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  return GiftCatalog(
    categories: ordered,
    giftsByCategory: {
      for (final cat in ordered) cat.id: byCategory[cat.id] ?? const [],
    },
    allItems: [for (final cat in ordered) ...?byCategory[cat.id]],
  );
}

GiftCatalog? _catalogFromCache(List<Map<String, dynamic>>? rows) {
  if (rows == null || rows.isEmpty) return null;
  final categoryMeta = <String, ShopCategory>{};
  final items = <ShopItem>[];
  for (final row in rows) {
    final catId = row['category_id']?.toString() ?? '';
    if (catId.isEmpty) continue;
    categoryMeta.putIfAbsent(
      catId,
      () => ShopCategory(
        id: catId,
        name: row['category_name']?.toString() ?? 'Gifts',
        iconUrl: (row['category_icon']?.toString().trim().isEmpty ?? true)
            ? null
            : row['category_icon']?.toString(),
        displayOrder: (row['category_order'] as num?)?.toInt() ?? 0,
      ),
    );
    items.add(ShopItem.fromCacheMap(row));
  }
  if (items.isEmpty) return null;
  return _catalogFromItems(items, categoryMeta: categoryMeta);
}

Future<GiftCatalog> _fetchGiftCatalog() async {
  final response = await supabase
      .from('shop_items')
      // `*` so show_duration_ms is read where migrated without failing the
      // whole catalog on a database that does not have the column yet.
      .select('*, shop_categories(id, name, icon_url, display_order)')
      .eq('is_gift', true)
      .eq('is_active', true)
      .order('price_coins', ascending: true);

  final categoryMeta = <String, ShopCategory>{};
  final items = <ShopItem>[];
  for (final raw in response as List) {
    final map = Map<String, dynamic>.from(raw as Map);
    final catRaw = map['shop_categories'];
    if (catRaw is Map) {
      final cat = ShopCategory.fromMap(Map<String, dynamic>.from(catRaw));
      categoryMeta[cat.id] = cat;
    }
    items.add(ShopItem.fromMap(map));
  }

  final catalog = _catalogFromItems(items, categoryMeta: categoryMeta);
  final cacheRows = <Map<String, dynamic>>[];
  for (final cat in catalog.categories) {
    for (final gift in catalog.giftsByCategory[cat.id] ?? const <ShopItem>[]) {
      cacheRows.add(
        gift.toCacheMap(
          categoryName: cat.name,
          categoryOrder: cat.displayOrder,
          categoryIcon: cat.iconUrl,
        ),
      );
    }
  }
  unawaited(HiveCacheService.saveGiftCatalog(cacheRows));
  return catalog;
}

/// Downloads the first page of gift icons into the disk/memory image cache so
/// the sheet does not show empty tiles after the catalog itself has arrived.
void prefetchGiftCatalogIcons(GiftCatalog catalog, {int limit = 16}) {
  if (catalog.isEmpty) return;
  final firstCategory = catalog.categories.first;
  final gifts = catalog.giftsByCategory[firstCategory.id] ?? const <ShopItem>[];
  final urls = <String>[];
  for (final gift in gifts.take(limit)) {
    final url = gift.imageUrl?.trim() ?? '';
    if (url.isEmpty) continue;
    final transformed =
        SupabaseImageTransform.url(
          url,
          width: 128,
          height: 128,
          resize: 'contain',
          quality: 75,
        ) ??
        url;
    urls.add(transformed);
  }
  if (urls.isEmpty) return;

  // Fire-and-forget: warm the shared disk cache. Decoding into memory waits
  // until a widget actually paints the image.
  for (final url in urls) {
    unawaited(
      AppImageCache.manager.getSingleFile(url).then(
        (_) {},
        onError: (Object e) {
          debugPrint('[GiftCatalog] icon prefetch failed: $e');
        },
      ),
    );
  }
}

/// Puts gift animations (SVGA and MP4) on disk ahead of the first send, so
/// the first play of each gift is the animation and not its listing PNG.
///
/// A fresh install had nothing on disk and only warmed 24 files on room
/// entry, so the first send of almost every gift downloaded live and lost
/// the race. Now every gift is warmed on Wi-Fi (the first [mobileLimit] on
/// mobile data), in sheet order, two at a time, once per URL per session.
void warmGiftCatalogAnimations(
  GiftCatalog catalog, {
  int mobileLimit = 60,
  int wifiLimit = 400,
}) {
  if (catalog.isEmpty) return;
  final svgas = <String>[];
  final videos = <String>[];
  for (final cat in catalog.categories) {
    for (final gift in catalog.giftsByCategory[cat.id] ?? const <ShopItem>[]) {
      final media = gift.svgaUrl?.trim() ?? '';
      if (media.isEmpty) continue;
      if (MediaUrlUtil.isSvgaUrl(media)) {
        svgas.add(media);
      } else if (MediaUrlUtil.isVideoUrl(media)) {
        videos.add(media);
      }
    }
  }
  if (svgas.isEmpty && videos.isEmpty) return;
  Timer(const Duration(seconds: 3), () async {
    var onWifi = false;
    try {
      final links = await Connectivity().checkConnectivity();
      onWifi =
          links.contains(ConnectivityResult.wifi) ||
          links.contains(ConnectivityResult.ethernet);
    } catch (_) {}
    final limit = onWifi ? wifiLimit : mobileLimit;
    debugPrint(
      '[gift_fx] warm start svga=${svgas.length} mp4=${videos.length} '
      'wifi=$onWifi limit=$limit',
    );
    final sw = Stopwatch()..start();
    await Future.wait([
      if (svgas.isNotEmpty) SvgaCache.warmDisk(svgas, limit: limit),
      if (videos.isNotEmpty)
        GiftVideoCache.prefetch(videos, limit: onWifi ? 80 : 12),
    ]);
    debugPrint('[gift_fx] warm done in ${sw.elapsedMilliseconds}ms');
  });
}

String _catalogFingerprint(GiftCatalog catalog) {
  return HiveCacheService.giftCatalogFingerprint([
    for (final cat in catalog.categories)
      for (final gift in catalog.giftsByCategory[cat.id] ?? const <ShopItem>[])
        gift.toCacheMap(
          categoryName: cat.name,
          categoryOrder: cat.displayOrder,
          categoryIcon: cat.iconUrl,
        ),
  ]);
}

final giftCatalogProvider = FutureProvider<GiftCatalog>((ref) async {
  final cached = _catalogFromCache(HiveCacheService.loadGiftCatalog());
  if (cached != null && !cached.isEmpty) {
    prefetchGiftCatalogIcons(cached);
    warmGiftCatalogAnimations(cached);
    final cachedFp = _catalogFingerprint(cached);
    // Paint from cache now. If the shop changed, refresh and rebuild once so
    // an open sheet picks up new gifts without waiting for an app restart.
    unawaited(() async {
      try {
        final fresh = await _fetchGiftCatalog();
        prefetchGiftCatalogIcons(fresh);
        warmGiftCatalogAnimations(fresh);
        if (_catalogFingerprint(fresh) != cachedFp) {
          ref.invalidateSelf();
        }
      } catch (e) {
        debugPrint('[GiftCatalog] background refresh failed: $e');
      }
    }());
    return cached;
  }

  final fresh = await _fetchGiftCatalog();
  prefetchGiftCatalogIcons(fresh);
  warmGiftCatalogAnimations(fresh);
  return fresh;
});

/// Starts the catalog fetch without opening the sheet. Call when a room opens
/// so the first gift-tap hits a warm provider (and usually a warm image cache).
void warmGiftCatalog(WidgetRef ref) {
  final async = ref.read(giftCatalogProvider);
  if (async.hasValue || async.isLoading) return;
  unawaited(ref.read(giftCatalogProvider.future).catchError((Object e) {
    debugPrint('[GiftCatalog] warm failed: $e');
    return const GiftCatalog(
      categories: [],
      giftsByCategory: {},
      allItems: [],
    );
  }));
}

/// Same warm for non-widget code that only has a [ProviderContainer]/Ref.
void warmGiftCatalogFromRef(Ref ref) {
  final async = ref.read(giftCatalogProvider);
  if (async.hasValue || async.isLoading) return;
  unawaited(ref.read(giftCatalogProvider.future).catchError((Object e) {
    debugPrint('[GiftCatalog] warm failed: $e');
    return const GiftCatalog(
      categories: [],
      giftsByCategory: {},
      allItems: [],
    );
  }));
}

final shopCategoriesProvider = FutureProvider<List<ShopCategory>>((ref) async {
  final response = await supabase
      .from('shop_categories')
      .select()
      .order('display_order', ascending: true);
  return (response as List).map((e) => ShopCategory.fromMap(e)).toList();
});

final shopItemsProvider = FutureProvider.family<List<ShopItem>, String>((
  ref,
  categoryId,
) async {
  final response = await supabase
      .from('shop_items')
      .select('*, shop_categories(name)')
      .eq('category_id', categoryId)
      .eq('is_active', true)
      .order('price_coins', ascending: true);
  return (response as List).map((e) => ShopItem.fromMap(e)).toList();
});

final giftCategoriesProvider = FutureProvider<List<ShopCategory>>((ref) async {
  final catalog = await ref.watch(giftCatalogProvider.future);
  return catalog.categories;
});

final giftItemsProvider = FutureProvider.family<List<ShopItem>, String>((
  ref,
  categoryId,
) async {
  final catalog = await ref.watch(giftCatalogProvider.future);
  return catalog.giftsByCategory[categoryId] ?? const [];
});
