import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum RoomSideFloatKind { event, game }

class RoomSideFloatItem {
  const RoomSideFloatItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.imageUrl,
    required this.sortOrder,
    this.partyEventId,
    this.gameSlug,
  });

  final String id;
  final RoomSideFloatKind kind;
  final String title;
  final String imageUrl;
  final int sortOrder;
  final String? partyEventId;
  final String? gameSlug;

  factory RoomSideFloatItem.fromMap(Map<String, dynamic> map) {
    final kindRaw = (map['kind'] as String?)?.toLowerCase();
    return RoomSideFloatItem(
      id: map['id']?.toString() ?? '',
      kind: kindRaw == 'game'
          ? RoomSideFloatKind.game
          : RoomSideFloatKind.event,
      title: (map['title'] as String?)?.trim() ?? '',
      imageUrl: (map['image_url'] as String?)?.trim() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      partyEventId: map['party_event_id']?.toString(),
      gameSlug: (map['game_slug'] as String?)?.trim(),
    );
  }
}

final roomSideFloatItemsProvider = FutureProvider<List<RoomSideFloatItem>>((
  ref,
) async {
  ref.keepAlive();
  try {
    final response = await Supabase.instance.client
        .from('room_side_float_items')
        .select(
          'id, kind, title, image_url, party_event_id, game_slug, sort_order, is_active',
        )
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((e) => RoomSideFloatItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  } catch (e) {
    debugPrint('[roomSideFloatItemsProvider] fetch failed: $e');
    return [];
  }
});
