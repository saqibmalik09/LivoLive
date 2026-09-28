import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomDecorationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await Supabase.instance.client
      .from('room_decorations')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final roomCustomBackgroundPriceProvider = FutureProvider<int>((ref) async {
  try {
    final res = await Supabase.instance.client.rpc(
      'get_room_custom_background_price',
    );
    if (res is num) return res.toInt();
    if (res is String) return int.tryParse(res) ?? 500;
    return 500;
  } catch (e) {
    debugPrint('[RoomDecoration] custom price error: $e');
    return 500;
  }
});

class RoomDecorationActions {
  static Future<Map<String, dynamic>> applyCatalogDecoration({
    required String roomId,
    required String decorationId,
  }) async {
    final res = await Supabase.instance.client.rpc(
      'apply_room_decoration',
      params: {'p_room_id': roomId, 'p_decoration_id': decorationId},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> applyCustomBackground({
    required String roomId,
    required String backgroundUrl,
  }) async {
    final res = await Supabase.instance.client.rpc(
      'apply_room_custom_background',
      params: {'p_room_id': roomId, 'p_background_url': backgroundUrl},
    );
    return Map<String, dynamic>.from(res as Map);
  }
}
