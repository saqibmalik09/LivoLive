import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/util/room_sort_utils.dart';

final topRoomByTopicProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((
      ref,
      topicSlug,
    ) async {
      try {
        final response = await Supabase.instance.client
            .from('active_rooms_with_rankings')
            .select('*')
            .eq('room_topic', topicSlug);

        final rooms = (response as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (rooms.isEmpty) return null;

        sortRoomsByPopularRanking(rooms);
        return rooms.first;
      } catch (_) {
        return null;
      }
    });
