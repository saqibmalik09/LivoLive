import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/wallet_coins_provider.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/room_media_keep_alive.dart';
import 'package:sk_live/core/services/room_minimized_keepalive.dart';

final minimizedRoomProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

final currentLiveRoomIdProvider = StateProvider<String?>((ref) => null);

final activeRoomSessionProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

final roomSystemBubbleVisibleProvider = StateProvider<bool>((ref) => false);

Map<String, dynamic> buildActiveRoomSession(Map<String, dynamic> room) {
  final bubbleAvatar = room['_bubble_avatar']?.toString().trim();
  return {
    'id': room['id'].toString(),
    'title': room['title'] ?? 'Room',
    'image_url': room['image_url'] ?? room['background_url'],
    'avatar_url': (bubbleAvatar != null && bubbleAvatar.isNotEmpty)
        ? bubbleAvatar
        : (room['image_url'] ?? room['background_url']),
    'muted': room['_bubble_muted'] == true,
  };
}

void syncActiveRoomSession(dynamic ref, Map<String, dynamic> room) {
  final session = buildActiveRoomSession(room);
  ref.read(activeRoomSessionProvider.notifier).state = session;
  RoomFloatingBubbleService.cacheSession(session);
}

void clearActiveRoomState(dynamic ref) {
  RoomMinimizedKeepAlive.stop();
  ref.read(activeRoomSessionProvider.notifier).state = null;
  ref.read(minimizedRoomProvider.notifier).state = null;
  ref.read(currentLiveRoomIdProvider.notifier).state = null;
  ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
  ref.read(walletCoinsOverrideProvider.notifier).state = null;
  RoomFloatingBubbleService.cacheSession(null);

  RoomMediaKeepAlive.disposeAll();
}

Map<String, dynamic>? resolveActiveRoomSession(dynamic ref) {
  final session = ref.read(activeRoomSessionProvider);
  if (session != null) return session;
  return ref.read(minimizedRoomProvider);
}
