import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomInvitationProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

  Future<void> load() async {
    try {
      final response = await supabase
          .from('room_invitations')
          .select(
            '*, room:room_id(title, image_url), inviter:inviter_id(username)',
          )
          .eq('invitee_id', user.id)
          .eq('status', 'pending')
          .inFilter('role', ['admin', 'seat'])
          .order('created_at', ascending: true);
      if (!controller.isClosed) {
        controller.add(List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('[RoomInvitation] load error: $e');
      if (!controller.isClosed) controller.add([]);
    }
  }

  final channel = supabase.channel('room_invites:${user.id}');
  channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_invitations',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'invitee_id',
          value: user.id,
        ),
        callback: (_) => load(),
      )
      .subscribe();

  load();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

class RoomInvitationActions {
  static Future<void> sendAdminInvitation({
    required String roomId,
    required String inviteeId,
  }) async {
    final supabase = Supabase.instance.client;
    final inviterId = supabase.auth.currentUser?.id;
    if (inviterId == null) return;

    final room = await supabase
        .from('rooms')
        .select('host_id, title')
        .eq('id', roomId)
        .single();

    if (room['host_id'] == inviteeId) {
      throw Exception('The room owner cannot be invited as sub-admin');
    }

    final existing = await supabase
        .from('room_members')
        .select('role')
        .eq('room_id', roomId)
        .eq('user_id', inviteeId)
        .maybeSingle();

    if (existing != null &&
        (existing['role'] == 'admin' || existing['role'] == 'host')) {
      throw Exception('This user is already a sub-admin');
    }

    final pending = await supabase
        .from('room_invitations')
        .select('id, role')
        .eq('room_id', roomId)
        .eq('invitee_id', inviteeId)
        .eq('status', 'pending')
        .maybeSingle();

    if (pending != null) {
      throw Exception('An invitation is already pending for this user');
    }

    await supabase.from('room_invitations').insert({
      'room_id': roomId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'role': 'admin',
      'status': 'pending',
    });
  }

  static Future<void> sendSeatInvitation({
    required String roomId,
    required String inviteeId,
    int? seatIndex,
  }) async {
    final supabase = Supabase.instance.client;
    final inviterId = supabase.auth.currentUser?.id;
    if (inviterId == null) return;

    if (inviteeId == inviterId) {
      throw Exception('You cannot invite yourself');
    }

    final onSeat = await supabase
        .from('room_seats')
        .select('id')
        .eq('room_id', roomId)
        .eq('user_id', inviteeId)
        .maybeSingle();

    if (onSeat != null) {
      throw Exception('User is already on a seat');
    }

    if (seatIndex != null) {
      final seatRow = await supabase
          .from('room_seats')
          .select('user_id, is_locked')
          .eq('room_id', roomId)
          .eq('seat_index', seatIndex)
          .maybeSingle();

      if (seatRow != null) {
        if (seatRow['is_locked'] == true) {
          throw Exception('That seat is locked');
        }
        if (seatRow['user_id'] != null) {
          throw Exception('That seat is already taken');
        }
      }
    }

    final pending = await supabase
        .from('room_invitations')
        .select('id')
        .eq('room_id', roomId)
        .eq('invitee_id', inviteeId)
        .eq('status', 'pending')
        .maybeSingle();

    if (pending != null) {
      throw Exception('An invitation is already pending for this user');
    }

    await supabase.from('room_invitations').insert({
      'room_id': roomId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'role': 'seat',
      'status': 'pending',
      if (seatIndex != null) 'seat_index': seatIndex,
    });
  }

  static Future<void> assignAdminBySearch({
    required String roomId,
    required String inviteeId,
  }) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final room = await supabase
        .from('rooms')
        .select('host_id')
        .eq('id', roomId)
        .single();

    if (room['host_id'] != userId) {
      throw Exception('Only the room owner can invite admins by search');
    }

    await sendAdminInvitation(roomId: roomId, inviteeId: inviteeId);
  }

  static Future<Map<String, dynamic>?> fetchPendingInvitation(
    String invitationId, {
    String? role,
  }) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    var query = supabase
        .from('room_invitations')
        .select(
          '*, room:room_id(title, image_url), inviter:inviter_id(username)',
        )
        .eq('id', invitationId)
        .eq('invitee_id', userId)
        .eq('status', 'pending');

    if (role != null) {
      query = query.eq('role', role);
    }

    final row = await query.maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  static Future<void> respondToInvitation(
    String invitationId,
    bool accept,
  ) async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final invite = await supabase
        .from('room_invitations')
        .select()
        .eq('id', invitationId)
        .eq('invitee_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    if (invite == null) {
      throw Exception('Invitation not found or already handled');
    }

    await supabase
        .from('room_invitations')
        .update({'status': accept ? 'accepted' : 'rejected'})
        .eq('id', invitationId);
  }
}
