import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

class RoomInviteHelper {
  RoomInviteHelper._();

  static Future<void> sendRoomInvite({
    required String targetUserId,
    required Map<String, dynamic> room,
    required String hostUsername,
  }) async {
    final conversationId = await ChatService.getOrCreateConversation(
      targetUserId,
    );
    await ChatService.sendMessage(
      conversationId: conversationId,
      type: 'text',
      content: 'Join my live room: ${room['title'] ?? 'Room'}',
      metadata: {
        'is_room_invite': true,
        'room_id': room['id'].toString(),
        'room_title': room['title'],
        'room_image_url': room['image_url'],
        'host_username': hostUsername,
      },
    );
  }

  static Future<void> openRoomFromInvite(
    BuildContext context,
    Map<String, dynamic>? metadata,
  ) async {
    final roomId = metadata?['room_id']?.toString();
    if (roomId == null || roomId.isEmpty) {
      _snack(context, 'Invalid room invite.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final room = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();

      if (context.mounted) Navigator.of(context).pop();

      if (room == null) {
        if (context.mounted) _snack(context, 'Room not found or has ended.');
        return;
      }
      if (room['is_active'] == false) {
        if (context.mounted) _snack(context, 'This room is no longer live.');
        return;
      }

      if (!context.mounted) return;
      final roomMap = Map<String, dynamic>.from(room);
      final allowed = await ensureRoomUnlockedForEntry(context, roomMap);
      if (!allowed || !context.mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RoomLiveScreen(room: roomMap)));
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) _snack(context, 'Could not open room.');
    }
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }
}
