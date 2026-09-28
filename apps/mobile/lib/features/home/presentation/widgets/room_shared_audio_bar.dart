import 'package:flutter/material.dart';

import '../../services/room_shared_audio_sync_controller.dart';

class RoomSharedAudioBar extends StatefulWidget {
  const RoomSharedAudioBar({super.key, required this.controller});

  final RoomSharedAudioSyncController controller;

  @override
  State<RoomSharedAudioBar> createState() => _RoomSharedAudioBarState();
}

class _RoomSharedAudioBarState extends State<RoomSharedAudioBar> {
  double? _dragPosition;

  String _formatTime(double seconds) {
    final total = seconds.floor();
    final m = (total ~/ 60).toString().padLeft(1, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller.session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Colors.cyanAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            session.isPlaying ? 'Playing for room' : 'Paused',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.controller.canControl) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () async {
                          await widget.controller.togglePlayPause();
                        },
                        icon: Icon(
                          session.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () async {
                          await widget.controller.stopAudio();
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<double>(
                  valueListenable: widget.controller.playbackPosition,
                  builder: (context, position, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: widget.controller.playbackDuration,
                      builder: (context, duration, __) {
                        final max = duration > 0
                            ? duration
                            : (session.duration > 0 ? session.duration : 1.0);
                        final value = (_dragPosition ?? position).clamp(
                          0.0,
                          max,
                        );
                        final canSeek = widget.controller.canControl;

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                activeTrackColor: Colors.cyanAccent,
                                inactiveTrackColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                thumbColor: Colors.cyanAccent,
                              ),
                              child: Slider(
                                value: value,
                                max: max,
                                onChanged: canSeek
                                    ? (v) => setState(() => _dragPosition = v)
                                    : null,
                                onChangeEnd: canSeek
                                    ? (v) async {
                                        setState(() => _dragPosition = null);
                                        await widget.controller.seekTo(v);
                                      }
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTime(value),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _formatTime(max),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.45,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
