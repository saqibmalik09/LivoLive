import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/media_url_util.dart';

final supabase = Supabase.instance.client;

class ShopCategory {
  final String id;
  final String name;
  final String? iconUrl;

  ShopCategory({required this.id, required this.name, this.iconUrl});

  factory ShopCategory.fromMap(Map<String, dynamic> map) {
    return ShopCategory(
      id: map['id'],
      name: map['name'],
      iconUrl: map['icon_url'],
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
  });

  factory ShopItem.fromMap(Map<String, dynamic> map) {
    int level = map['required_vip_level'] ?? 0;
    final name = map['name'] ?? '';
    if (level == 0 && name.toString().startsWith('VIP')) {
      final match = RegExp(r'VIP\s*(\d+)').firstMatch(name);
      if (match != null) {
        level = int.parse(match.group(1)!);
      }
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
      categoryName: map['shop_categories']?['name'],
      isGift: map['is_gift'] ?? false,
      isFullScreen: map['is_full_screen'] ?? false,
    );
  }
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
  final response = await supabase
      .from('shop_items')
      .select('category_id, shop_categories!inner(*)')
      .eq('is_gift', true)
      .eq('is_active', true);

  final Map<String, ShopCategory> categories = {};
  for (var item in response as List) {
    final catMap = item['shop_categories'];
    if (catMap != null) {
      final cat = ShopCategory.fromMap(catMap);
      categories[cat.id] = cat;
    }
  }

  final list = categories.values.toList();
  return list;
});

final giftItemsProvider = FutureProvider.family<List<ShopItem>, String>((
  ref,
  categoryId,
) async {
  final response = await supabase
      .from('shop_items')
      .select('*, shop_categories(name)')
      .eq('category_id', categoryId)
      .eq('is_gift', true)
      .eq('is_active', true)
      .order('price_coins', ascending: true);
  return (response as List).map((e) => ShopItem.fromMap(e)).toList();
});
