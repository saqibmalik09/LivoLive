import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/room_media_keep_alive.dart';
import 'package:sk_live/core/services/room_minimized_keepalive.dart';
import 'package:sk_live/core/services/room_voice_session_service.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';
import 'package:sk_live/features/home/services/room_live_broadcast.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:sk_live/features/home/services/room_shared_audio_sync_controller.dart';

class RoomExitCoordinator {
  RoomExitCoordinator._();

  static int _liveEpoch = 0;
  static String? _liveRoomId;

  static void noteRoomLive(String roomId) {
    final id = roomId.trim();
    if (id.isEmpty) return;
    _liveRoomId = id;
    _liveEpoch++;
  }

  static bool shouldAbortTeardown(String roomId, int leaveEpoch) {
    return _liveRoomId == roomId && _liveEpoch > leaveEpoch;
  }

  static int get liveEpoch => _liveEpoch;

  static Future<bool> leaveRoom(
    WidgetRef ref, {
    required String roomId,
    bool hideBubble = true,
  }) async {
    final sw = Stopwatch()..start();
    final wasLive = ref.read(currentLiveRoomIdProvider) == roomId;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final profile = ref.read(userProfileProvider).value;
    final user = <String, dynamic>{
      'id': profile?['id'] ?? userId,
      'username': profile?['username'],
      'avatar_url': profile?['avatar_url'],
    };

    final leaveEpoch = _liveEpoch;
    if (_liveRoomId == roomId) {
      _liveRoomId = null;
    }

    RoomMinimizedKeepAlive.stop();
    OrbitVoiceSessionService.silenceForExit(roomId: roomId);
    unawaited(_silenceMediaNow(roomId));

    clearActiveRoomState(ref);

    var popped = false;
    if (wasLive) {
      final nav = AppRouter.navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        popped = true;
      }
    }
    debugPrint('[EXIT] popped=$popped in ${sw.elapsedMilliseconds}ms');

    if (hideBubble) {
      unawaited(
        RoomFloatingBubbleService.hideRoomBubble(
          reason: RoomBubbleHideReason.roomExit,
        ),
      );
    }

    unawaited(
      _finishLeaveInBackground(
        roomId: roomId,
        userId: userId,
        user: user,
        sw: sw,
        leaveEpoch: leaveEpoch,
      ),
    );
    return popped;
  }

  static Future<void> _silenceMediaNow(String roomId) async {
    try {
      await RoomSharedAudioSyncController.stopIfCurrentUserIsUploader(roomId);
    } catch (e) {
      debugPrint('[EXIT] sharedAudio stop broadcast: $e');
    }
    try {
      await RoomSharedAudioSyncController.haltPlaybackForRoom(roomId);
    } catch (e) {
      debugPrint('[EXIT] sharedAudio room: $e');
    }
    try {
      await RoomSharedAudioSyncController.haltAllPlayback();
    } catch (e) {
      debugPrint('[EXIT] sharedAudio: $e');
    }
    try {
      await RoomMediaKeepAlive.disposeAll();
    } catch (e) {
      debugPrint('[EXIT] mediaKeepAlive: $e');
    }
  }

  static Future<void> _finishLeaveInBackground({
    required String roomId,
    required String? userId,
    required Map<String, dynamic> user,
    required Stopwatch sw,
    required int leaveEpoch,
  }) async {
    bool sameRoomLiveAgain() => shouldAbortTeardown(roomId, leaveEpoch);

    if (sameRoomLiveAgain()) {
      debugPrint(
        '[EXIT] abort teardown — room $roomId live again '
        '(epoch $leaveEpoch→$_liveEpoch)',
      );
      return;
    }

    try {
      await OrbitVoiceSessionService.stopLocalAudioForExit(roomId: roomId);
    } catch (e) {
      debugPrint('[EXIT] orbit local audio: $e');
    }
    if (sameRoomLiveAgain()) {
      debugPrint('[EXIT] abort before stopPublish — room live again');
      return;
    }
    try {
      await OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId);
    } catch (e) {
      debugPrint('[EXIT] orbit leave: $e');
    }

    if (sameRoomLiveAgain()) {
      debugPrint('[EXIT] abort after orbit leave — room live again');
      return;
    }

    try {
      await RoomVoiceSessionService.stopAllRemotePlayback();
      await RoomVoiceSessionService.stopLocalPublish();
      unawaited(RoomVoiceSessionService.logoutRoomFast(roomId));
    } catch (e) {
      debugPrint('[EXIT] voice stubs: $e');
    }

    if (sameRoomLiveAgain()) {
      debugPrint('[EXIT] abort before gateway leave — room live again');
      return;
    }

    if (AppConstants.useRealtimeGateway && userId != null) {
      try {
        await RoomRealtimeSocket.instance
            .seatLeave({
              'roomId': roomId,
              'user_id': userId,
              'event_id': RoomLiveBroadcast.newEventId(),
            })
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('[EXIT] gateway seatLeave: $e');
      }
      if (sameRoomLiveAgain()) {
        debugPrint('[EXIT] abort before leaveRoom — room live again');
        return;
      }
      try {
        await RoomRealtimeSocket.instance
            .leaveRoom(roomId: roomId, user: user)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[EXIT] gateway leaveRoom: $e');
      }
    }

    if (sameRoomLiveAgain()) {
      debugPrint('[EXIT] abort before leaveVoiceRoom — room live again');
      return;
    }

    try {
      await RoomVoiceSessionService.leaveVoiceRoom(
        roomId,
        userId,
        skipSeatDelete: AppConstants.useRealtimeGateway,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('[EXIT] leaveVoiceRoom: $e');
    }
    debugPrint('[EXIT] teardown done in ${sw.elapsedMilliseconds}ms');
  }

  static void returnToRoom(WidgetRef ref) {
    final liveRoomId = ref.read(currentLiveRoomIdProvider);
    if (liveRoomId != null) {
      return;
    }

    final session =
        ref.read(activeRoomSessionProvider) ?? ref.read(minimizedRoomProvider);
    if (session == null) return;

    final room = ref.read(minimizedRoomProvider) ?? session;

    final navCtx = AppRouter.navigatorKey.currentContext;
    if (navCtx == null) return;

    final roomId = room['id']?.toString();
    if (roomId != null) {
      ref.read(currentLiveRoomIdProvider.notifier).state = roomId;
      ref.read(minimizedRoomProvider.notifier).state = null;
      ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
    }

    unawaited(
      openRoomLive(
        navCtx,
        Map<String, dynamic>.from(room),
        skipLockCheck: true,
      ),
    );
  }
}
