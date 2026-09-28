import 'package:flutter/services.dart';

class RoomBubbleNativeBridge {
  RoomBubbleNativeBridge._();

  static const MethodChannel _overlayChannel = MethodChannel(
    'com.sklive.app/room_bubble',
  );

  static const MethodChannel mainChannel = MethodChannel(
    'com.sklive.app/room_bubble_main',
  );

  static Future<bool> bringAppToForeground({
    required String action,
    required String roomId,
  }) async {
    try {
      final result = await _overlayChannel.invokeMethod<bool>(
        'bringToForeground',
        {'action': action, 'roomId': roomId},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cacheRoomId(String roomId) async {
    if (roomId.isEmpty) return;
    try {
      await _overlayChannel.invokeMethod<void>('cacheRoomId', {
        'roomId': roomId,
      });
    } catch (_) {}
  }

  static Future<void> acknowledgePendingAction() async {
    try {
      await mainChannel.invokeMethod<void>('acknowledgePendingAction');
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> consumePendingAction() async {
    try {
      final result = await mainChannel.invokeMethod<dynamic>(
        'consumePendingAction',
      );
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}
    return null;
  }
}
