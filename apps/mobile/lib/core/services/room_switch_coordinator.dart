import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/room_media_keep_alive.dart';
import 'package:sk_live/core/services/room_minimized_keepalive.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';
import 'package:sk_live/features/home/services/room_shared_audio_sync_controller.dart';

class RoomSwitchCoordinator {
  RoomSwitchCoordinator._();

  static String? _enteringRoomId;

  static void markEnteringRoom(String roomId) {
    _enteringRoomId = roomId;
  }

  static String? get enteringRoomId => _enteringRoomId;

  static void clearEnteringRoom(String roomId) {
    if (_enteringRoomId == roomId) {
      _enteringRoomId = null;
    }
  }

  static bool isSwitchingToAnotherLiveRoom(String roomId) {
    final entering = _enteringRoomId;
    return entering != null && entering != roomId;
  }

  static Future<void> prepareEnterRoom({
    required dynamic ref,
    required String enteringRoomId,
    bool retainResumedMedia = false,
  }) async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final toCleanup = <String, Map<String, dynamic>?>{};

    final liveId = ref.read(currentLiveRoomIdProvider);
    if (liveId != null && liveId != enteringRoomId) {
      toCleanup[liveId] = ref.read(activeRoomSessionProvider);
    }

    final session = ref.read(activeRoomSessionProvider);
    final sessionId = session?['id']?.toString();
    if (sessionId != null && sessionId != enteringRoomId) {
      toCleanup[sessionId] = session;
    }

    final minimized = ref.read(minimizedRoomProvider);
    final minimizedId = minimized?['id']?.toString();
    if (minimizedId != null && minimizedId != enteringRoomId) {
      toCleanup[minimizedId] = minimized;
    }

    final keepAliveId = RoomMediaKeepAlive.roomId;
    if (keepAliveId != null && keepAliveId != enteringRoomId) {
      toCleanup.putIfAbsent(keepAliveId, () => null);
    }

    if (toCleanup.isEmpty) {
      _deferClearEnteringRoom(enteringRoomId);
      return;
    }

    try {
      await RoomSharedAudioSyncController.haltPlaybackExceptRoom(
        enteringRoomId,
      );

      if (!retainResumedMedia) {
        await RoomMediaKeepAlive.disposeAll();
      } else {
        final keepId = RoomMediaKeepAlive.roomId;
        if (keepId != null && keepId != enteringRoomId) {
          await RoomMediaKeepAlive.disposeAll();
        }
      }

      RoomMinimizedKeepAlive.stop();

      for (final entry in toCleanup.entries) {
        debugPrint(
          '[RoomSwitch] cleanup previous=${entry.key} entering=$enteringRoomId',
        );
        OrbitVoiceSessionService.silenceForExit(roomId: entry.key);
        unawaited(RoomLiveScreen.cleanupRoomStatic(entry.key, myId));
      }

      if (minimizedId != null && minimizedId != enteringRoomId) {
        ref.read(minimizedRoomProvider.notifier).state = null;
      }

      await RoomFloatingBubbleService.hideRoomBubble(
        reason: RoomBubbleHideReason.roomExit,
      );
    } finally {
      _deferClearEnteringRoom(enteringRoomId);
    }
  }

  static void _deferClearEnteringRoom(String enteringRoomId) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      clearEnteringRoom(enteringRoomId);
    });
  }
}
