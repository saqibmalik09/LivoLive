import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart'
    show roomListColumns;
import 'package:supabase_flutter/supabase_flutter.dart';

final pinnedPartyRoomsProvider =
    FutureProvider.autoDispose<Map<int, Map<String, dynamic>>>((ref) async {
      final response = await Supabase.instance.client
          .from('active_rooms_with_rankings')
          .select(roomListColumns)
          .eq('is_pinned', true)
          .gte('pin_order', 1)
          .lte('pin_order', 3)
          .order('pin_order', ascending: true)
          .limit(3);

      final out = <int, Map<String, dynamic>>{};
      for (final row in response as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final slot = (map['pin_order'] as num?)?.toInt() ?? 0;
        if (slot < 1 || slot > 3) continue;
        final id = map['id']?.toString();
        if (id == null || id.isEmpty) continue;
        out.putIfAbsent(slot, () => map);
      }
      return out;
    });
