import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/features/home/presentation/widgets/room_youtube_player_host.dart';
import 'package:sk_live/features/home/services/room_shared_audio_queue_controller.dart';
import 'package:sk_live/features/home/services/room_shared_audio_sync_controller.dart';
import 'package:sk_live/features/home/services/room_youtube_sync_controller.dart';

class RoomMediaKeepAlive {
  RoomMediaKeepAlive._();

  static String? roomId;
  static RoomYoutubeSyncController? youtube;
  static RoomSharedAudioSyncController? sharedAudio;
  static RoomSharedAudioQueueController? sharedAudioQueue;

  static OverlayEntry? _minimizedYoutubeEntry;
  static bool _ensureScheduled = false;

  static bool get hasMedia => youtube != null || sharedAudio != null;

  static bool hostsRoom(String id) => roomId == id && hasMedia;

  static void retain({
    required String forRoomId,
    required RoomYoutubeSyncController youtubeSync,
    required RoomSharedAudioSyncController sharedAudioSync,
    RoomSharedAudioQueueController? sharedAudioQueueController,
  }) {
    roomId = forRoomId;
    youtube = youtubeSync;
    sharedAudio = sharedAudioSync;
    sharedAudioQueue = sharedAudioQueueController;
    debugPrint('[MediaKeepAlive] retained room=$forRoomId');
    startMinimizedYoutubeAudio();
  }

  static ({
    RoomYoutubeSyncController youtube,
    RoomSharedAudioSyncController sharedAudio,
    RoomSharedAudioQueueController? sharedAudioQueue,
  })?
  takeForResume(String forRoomId) {
    if (roomId != forRoomId || youtube == null || sharedAudio == null) {
      return null;
    }
    final y = youtube!;
    final a = sharedAudio!;
    final q = sharedAudioQueue;
    stopMinimizedYoutubeAudio();
    youtube = null;
    sharedAudio = null;
    sharedAudioQueue = null;
    roomId = null;
    debugPrint('[MediaKeepAlive] taken for resume room=$forRoomId');
    return (youtube: y, sharedAudio: a, sharedAudioQueue: q);
  }

  static void startMinimizedYoutubeAudio() {
    _scheduleEnsureMinimizedOverlay();
  }

  static void stopMinimizedYoutubeAudio() {
    _removeMinimizedOverlay();
  }

  static void _scheduleEnsureMinimizedOverlay() {
    if (_ensureScheduled) return;
    _ensureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureScheduled = false;
      _ensureMinimizedOverlayNow();
    });
  }

  static void _ensureMinimizedOverlayNow() {
    if (youtube == null || youtube?.isPlayerVisible != true) {
      _removeMinimizedOverlay();
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      _scheduleEnsureMinimizedOverlay();
      return;
    }

    final overlay = AppRouter.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      _scheduleEnsureMinimizedOverlay();
      return;
    }

    if (_minimizedYoutubeEntry != null) {
      _minimizedYoutubeEntry!.markNeedsBuild();
      return;
    }

    _minimizedYoutubeEntry = OverlayEntry(
      builder: (context) => const _MinimizedYoutubeAudioHost(),
    );
    overlay.insert(_minimizedYoutubeEntry!);
    debugPrint('[MediaKeepAlive] minimized youtube audio host inserted');
  }

  static void _removeMinimizedOverlay() {
    _minimizedYoutubeEntry?.remove();
    _minimizedYoutubeEntry = null;
  }

  static Future<void> disposeAll() async {
    stopMinimizedYoutubeAudio();
    final y = youtube;
    final a = sharedAudio;
    final q = sharedAudioQueue;
    youtube = null;
    sharedAudio = null;
    sharedAudioQueue = null;
    roomId = null;
    try {
      await q?.dispose();
    } catch (_) {}
    try {
      await a?.dispose();
    } catch (_) {}
    try {
      y?.dispose();
    } catch (_) {}
  }
}

class _MinimizedYoutubeAudioHost extends StatelessWidget {
  const _MinimizedYoutubeAudioHost();

  @override
  Widget build(BuildContext context) {
    final sync = RoomMediaKeepAlive.youtube;
    if (sync == null) return const SizedBox.shrink();
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: RoomYoutubePlayerHost(controller: sync),
      ),
    );
  }
}
