import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

final userActiveRoomProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, userId) {
      final seatStream = _supabase
          .from('room_seats')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .limit(1);

      return seatStream.switchMap((seats) {
        if (seats.isEmpty) {
          return Stream<Map<String, dynamic>?>.value(null);
        }
        final roomId = seats.first['room_id'];
        if (roomId == null) {
          return Stream<Map<String, dynamic>?>.value(null);
        }
        return _supabase
            .from('rooms')
            .stream(primaryKey: ['id'])
            .eq('id', roomId)
            .limit(1)
            .map((rooms) => rooms.isNotEmpty ? rooms.first : null);
      });
    });
