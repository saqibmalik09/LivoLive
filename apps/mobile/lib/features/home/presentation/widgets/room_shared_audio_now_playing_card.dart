import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/room_shared_audio_queue_controller.dart';
import '../../services/room_shared_audio_sync_controller.dart';

class RoomSharedAudioNowPlayingCard extends StatefulWidget {
  const RoomSharedAudioNowPlayingCard({
    super.key,
    required this.sync,
    required this.queue,
  });

  final RoomSharedAudioSyncController sync;
  final RoomSharedAudioQueueController queue;

  @override
  State<RoomSharedAudioNowPlayingCard> createState() =>
      _RoomSharedAudioNowPlayingCardState();
}

class _RoomSharedAudioNowPlayingCardState
    extends State<RoomSharedAudioNowPlayingCard> {
  double? _dragPosition;
  bool _volumeDragging = false;
  double? _dragVolume;

  RoomSharedAudioSyncController get _sync => widget.sync;

  String _formatTime(double seconds) {
    final total = seconds.floor();
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _sync.session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.15),
                  Colors.purpleAccent.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      color: Colors.cyanAccent,
                    ),
                    const SizedBox(width: 12),
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            session.isPlaying
                                ? 'Playing for room • ${session.startedByName ?? 'User'}'
                                : 'Paused • ${session.startedByName ?? 'User'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_sync.canControl) ...[
                      IconButton(
                        onPressed: () => _sync.togglePlayPause(),
                        icon: Icon(
                          session.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          widget.queue.cancelAutoAdvance();
                          _sync.stopAudio();
                        },
                        icon: const Icon(
                          Icons.stop_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
                _buildProgressRow(session.duration),
                _buildVolumeRow(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressRow(double sessionDuration) {
    final canSeek = _sync.canControl;
    return ValueListenableBuilder<double>(
      valueListenable: _sync.playbackPosition,
      builder: (context, position, _) {
        return ValueListenableBuilder<double>(
          valueListenable: _sync.playbackDuration,
          builder: (context, duration, _) {
            final max = duration > 1
                ? duration
                : (sessionDuration > 1 ? sessionDuration : 0.0);
            final ready = max > 1;

            final value = ready
                ? (_dragPosition ?? position).clamp(0.0, max)
                : 0.0;

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
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: Colors.cyanAccent,
                    disabledActiveTrackColor: Colors.cyanAccent.withValues(
                      alpha: 0.6,
                    ),
                    disabledInactiveTrackColor: Colors.white.withValues(
                      alpha: 0.15,
                    ),
                    disabledThumbColor: Colors.cyanAccent.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    max: ready ? max : 1.0,
                    onChanged: canSeek && ready
                        ? (v) => setState(() => _dragPosition = v)
                        : null,
                    onChangeEnd: canSeek && ready
                        ? (v) {
                            setState(() => _dragPosition = null);
                            unawaited(_sync.seekTo(v));
                          }
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(ready ? value : position),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        ready ? _formatTime(max) : '--:--',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
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
    );
  }

  Widget _buildVolumeRow() {
    final canSet = _sync.canControl;
    return AnimatedBuilder(
      animation: Listenable.merge([
        _sync.playbackVolume,
        _sync.effectiveVolume,
      ]),
      builder: (context, _) {
        final volume =
            (_volumeDragging
                    ? (_dragVolume ?? _sync.playbackVolume.value)
                    : _sync.effectiveVolume.value)
                .clamp(0.0, 1.0);
        return Row(
          children: [
            Icon(
              volume <= 0.01
                  ? Icons.volume_off_rounded
                  : (volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded),
              color: Colors.white70,
              size: 20,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  activeTrackColor: Colors.purpleAccent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                  thumbColor: Colors.purpleAccent,
                  disabledActiveTrackColor: Colors.purpleAccent.withValues(
                    alpha: 0.6,
                  ),
                  disabledInactiveTrackColor: Colors.white.withValues(
                    alpha: 0.15,
                  ),
                  disabledThumbColor: Colors.purpleAccent.withValues(
                    alpha: 0.6,
                  ),
                ),
                child: Slider(
                  value: volume,
                  onChangeStart: canSet
                      ? (v) {
                          _sync.beginVolumeDrag();
                          setState(() {
                            _volumeDragging = true;
                            _dragVolume = v;
                          });
                        }
                      : null,
                  onChanged: canSet
                      ? (v) {
                          setState(() => _dragVolume = v);
                          unawaited(_sync.previewVolume(v));
                        }
                      : null,
                  onChangeEnd: canSet
                      ? (v) {
                          _sync.endVolumeDrag();
                          setState(() {
                            _volumeDragging = false;
                            _dragVolume = null;
                          });
                          unawaited(_sync.setVolume(v));
                        }
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '${(volume * 100).round()}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class RoomSharedAudioMiniPlayerSheet extends StatelessWidget {
  const RoomSharedAudioMiniPlayerSheet({
    super.key,
    required this.sync,
    required this.queue,
  });

  final RoomSharedAudioSyncController sync;
  final RoomSharedAudioQueueController queue;

  static Future<void> show(
    BuildContext context, {
    required RoomSharedAudioSyncController sync,
    required RoomSharedAudioQueueController queue,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RoomSharedAudioMiniPlayerSheet(sync: sync, queue: queue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Now playing',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          ValueListenableBuilder(
            valueListenable: sync.session,
            builder: (context, session, _) {
              if (session == null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                  child: Text(
                    'No audio is playing in this room right now.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return RoomSharedAudioNowPlayingCard(sync: sync, queue: queue);
            },
          ),
        ],
      ),
    );
  }
}
