import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomMicEmoji {
  const RoomMicEmoji({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.svgaUrl,
    this.isPremium = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String? svgaUrl;
  final bool isPremium;
  final int sortOrder;

  factory RoomMicEmoji.fromMap(Map<String, dynamic> map) {
    return RoomMicEmoji(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Emoji',
      imageUrl: map['image_url']?.toString() ?? '',
      svgaUrl: map['svga_url']?.toString(),
      isPremium: map['is_premium'] == true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

final roomMicEmojisCatalogProvider = FutureProvider<List<RoomMicEmoji>>((
  ref,
) async {
  final response = await Supabase.instance.client
      .from('room_mic_emojis')
      .select('id, name, image_url, svga_url, is_premium, sort_order')
      .eq('is_active', true)
      .order('sort_order', ascending: true)
      .order('created_at', ascending: true);

  return (response as List)
      .map((row) => RoomMicEmoji.fromMap(Map<String, dynamic>.from(row)))
      .where((e) => e.imageUrl.isNotEmpty)
      .toList();
});

final roomMicEmojisForUserProvider = FutureProvider<List<RoomMicEmoji>>((
  ref,
) async {
  final catalog = await ref.watch(roomMicEmojisCatalogProvider.future);
  final profile = ref.watch(userProfileProvider).value;
  final vipLevel = (profile?['vip_level'] as num?)?.toInt() ?? 0;
  final isVip = vipLevel > 0;

  return catalog
      .where((emoji) => !emoji.isPremium || isVip)
      .toList(growable: false);
});

int userVipLevelFromProfile(Map<String, dynamic>? profile) {
  return (profile?['vip_level'] as num?)?.toInt() ?? 0;
}
