import 'package:supabase_flutter/supabase_flutter.dart';

class RoomMicEmojiSendResult {
  const RoomMicEmojiSendResult({
    required this.success,
    this.error,
    this.messageId,
  });

  final bool success;
  final String? error;
  final String? messageId;
}

Future<RoomMicEmojiSendResult> sendRoomMicEmoji({
  required SupabaseClient supabase,
  required String roomId,
  required String emojiId,
  required int seatIndex,
}) async {
  try {
    final response = await supabase.rpc(
      'send_room_mic_emoji',
      params: {
        'p_room_id': roomId,
        'p_emoji_id': emojiId,
        'p_seat_index': seatIndex,
      },
    );

    if (response == null) {
      return const RoomMicEmojiSendResult(
        success: false,
        error: 'No response from server',
      );
    }

    final map = Map<String, dynamic>.from(response as Map);
    if (map['success'] != true) {
      return RoomMicEmojiSendResult(
        success: false,
        error: map['error']?.toString() ?? 'Send failed',
      );
    }

    return RoomMicEmojiSendResult(
      success: true,
      messageId: map['message_id']?.toString(),
    );
  } catch (e) {
    return RoomMicEmojiSendResult(success: false, error: e.toString());
  }
}
