import 'package:flutter/material.dart';

import '../../services/room_youtube_session.dart';
import '../../services/room_youtube_sync_controller.dart';

class RoomYoutubePlayerHost extends StatelessWidget {
  const RoomYoutubePlayerHost({super.key, required this.controller});

  final RoomYoutubeSyncController controller;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoomYoutubeSession?>(
      valueListenable: controller.session,
      builder: (context, session, _) {
        if (session == null || !session.isActive) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(_radius),
                elevation: 4,
                shadowColor: Colors.black54,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius),
                    clipBehavior: Clip.antiAlias,
                    child: _YoutubePlayerSurface(
                      key: ValueKey(session.videoId),
                      controller: controller,
                      session: session,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YoutubePlayerSurface extends StatelessWidget {
  const _YoutubePlayerSurface({
    super.key,
    required this.controller,
    required this.session,
  });

  final RoomYoutubeSyncController controller;
  final RoomYoutubeSession session;

  @override
  Widget build(BuildContext context) {
    return controller.backend.buildPlayer(
      videoId: session.videoId,
      startAtSeconds: session.startAtSeconds,
      autoPlay: session.isPlaying,
      showControls: session.canControl,
    );
  }
}
