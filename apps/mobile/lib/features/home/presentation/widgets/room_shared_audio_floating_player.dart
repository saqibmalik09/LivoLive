import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/device_audio_library.dart';
import '../../services/room_shared_audio_queue_controller.dart';
import '../../services/room_shared_audio_session.dart';
import '../../services/room_shared_audio_sync_controller.dart';

class RoomSharedAudioFloatingPlayer extends StatefulWidget {
  const RoomSharedAudioFloatingPlayer({
    super.key,
    required this.sync,
    required this.queue,
    this.onOpenLibrary,
    this.bottomInset = 72,
    this.topInset = 56,
  });

  final RoomSharedAudioSyncController sync;
  final RoomSharedAudioQueueController queue;
  final VoidCallback? onOpenLibrary;
  final double bottomInset;
  final double topInset;

  @override
  RoomSharedAudioFloatingPlayerState createState() =>
      RoomSharedAudioFloatingPlayerState();
}

class RoomSharedAudioFloatingPlayerState
    extends State<RoomSharedAudioFloatingPlayer>
    with TickerProviderStateMixin {
  static const double _panelWidth = 292;
  static const double _panelHeight = 88;
  static const double _bubbleSize = 64;

  bool _minimized = false;
  bool _wasActive = false;
  bool _didDrag = false;
  bool _volumeDragging = false;
  double? _dragVolume;
  Offset? _position;

  late AnimationController _pulse;
  late AnimationController _spin;
  late AnimationController _ripple;

  RoomSharedAudioSyncController get _sync => widget.sync;
  RoomSharedAudioQueueController get _queue => widget.queue;

  double get _widgetWidth => _showsPanel ? _panelWidth : _bubbleSize;
  double get _widgetHeight => _showsPanel ? _panelHeight : _bubbleSize;

  bool get _canShowPanel => _sync.canControl;

  bool get _showsPanel => _canShowPanel && !_minimized;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    widget.sync.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.sync.session.removeListener(_onSessionChanged);
    _pulse.dispose();
    _spin.dispose();
    _ripple.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final active = widget.sync.session.value?.isActive == true;
    var needsRebuild = false;
    if (!active) {
      if (_wasActive || _position != null || _minimized) needsRebuild = true;
      _minimized = false;
      _position = null;
      _wasActive = false;
      _volumeDragging = false;
      _dragVolume = null;
    } else if (!_wasActive) {
      _minimized = !_canShowPanel;
      _wasActive = true;
      needsRebuild = true;
    } else if (!_canShowPanel && !_minimized) {
      _minimized = true;
      needsRebuild = true;
    }
    if (needsRebuild && mounted && !_volumeDragging) setState(() {});
  }

  void expand() {
    if (!mounted || !_canShowPanel) return;
    setState(() => _minimized = false);
  }

  void _toggleMinimized() {
    if (!_canShowPanel) return;
    setState(() => _minimized = !_minimized);
  }

  Offset _defaultPosition(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    return Offset(
      size.width - pad.right - _widgetWidth - 12,
      size.height - pad.bottom - widget.bottomInset - _widgetHeight - 8,
    );
  }

  Offset _clampPosition(Offset pos, BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final minX = pad.left + 6;
    final maxX = math.max(minX, screen.width - pad.right - _widgetWidth - 6);
    final minY = pad.top + widget.topInset;
    final maxY = math.max(
      minY,
      screen.height - pad.bottom - widget.bottomInset - _widgetHeight,
    );
    return Offset(pos.dx.clamp(minX, maxX), pos.dy.clamp(minY, maxY));
  }

  void _onPanUpdate(DragUpdateDetails d, BuildContext context) {
    _didDrag = true;
    setState(() {
      final base = _position ?? _defaultPosition(context);
      _position = _clampPosition(base + d.delta, context);
    });
  }

  void _syncPlaybackAnimations(bool playing) {
    if (playing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
      if (!_spin.isAnimating) _spin.repeat();
      if (!_ripple.isAnimating) _ripple.repeat();
    } else {
      _pulse.stop();
      _spin.stop();
      _ripple.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _sync.session,
      builder: (context, session, _) {
        if (session == null || !session.isActive) {
          return const SizedBox.shrink();
        }

        final pos = _clampPosition(
          _position ?? _defaultPosition(context),
          context,
        );

        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: _showsPanel ? _buildPanel(session) : _buildBubble(session),
        );
      },
    );
  }

  Widget _wrapDraggable({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onPanStart: (_) => _didDrag = false,
      onPanUpdate: (d) => _onPanUpdate(d, context),
      onPanEnd: (_) => Future<void>.delayed(
        const Duration(milliseconds: 80),
        () => _didDrag = false,
      ),
      onTap: () {
        if (!_didDrag) onTap?.call();
      },
      child: child,
    );
  }

  Widget _buildBubble(RoomSharedAudioSession session) {
    final playing = session.isPlaying;
    _syncPlaybackAnimations(playing);

    return _wrapDraggable(
      onTap: _canShowPanel ? _toggleMinimized : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _spin, _ripple]),
        builder: (context, _) {
          final breathe = 1.0 + _pulse.value * 0.06;
          final glow = playing ? 0.45 + _pulse.value * 0.35 : 0.22;

          return SizedBox(
            width: _bubbleSize + 20,
            height: _bubbleSize + 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (playing) ...[
                  _rippleRing(0.0, 0.28),
                  _rippleRing(0.33, 0.18),
                  _rippleRing(0.66, 0.1),
                ],
                Transform.scale(
                  scale: breathe,
                  child: Container(
                    width: _bubbleSize,
                    height: _bubbleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF00E5FF,
                          ).withValues(alpha: glow),
                          blurRadius: 18 + _pulse.value * 14,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFF7C4DFF,
                          ).withValues(alpha: glow * 0.7),
                          blurRadius: 28 + _pulse.value * 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: _spin.value * math.pi * 2,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Color(0xFF00E5FF),
                                  Color(0xFF7C4DFF),
                                  Color(0xFFFF6AD5),
                                  Color(0xFF00E5FF),
                                ],
                                stops: [0.0, 0.35, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF1A1035).withValues(alpha: 0.95),
                                const Color(0xFF0D1B2A).withValues(alpha: 0.98),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (playing) _soundBars(),
                              Icon(
                                playing
                                    ? Icons.music_note_rounded
                                    : Icons.music_off_rounded,
                                color: Colors.white.withValues(
                                  alpha: playing ? 0.95 : 0.7,
                                ),
                                size: 24,
                              ),
                              if (playing)
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF76FF03),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black87,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF76FF03,
                                          ).withValues(alpha: 0.8),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rippleRing(double phaseOffset, double maxAlpha) {
    final t = (_ripple.value + phaseOffset) % 1.0;
    final scale = 0.85 + t * 0.55;
    final alpha = maxAlpha * (1.0 - t);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: _bubbleSize,
        height: _bubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: alpha),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _soundBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final wave = math.sin((_pulse.value * math.pi * 2) + i * 1.2);
        final h = 6.0 + (wave.abs() * 10);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 2.5,
            height: h,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPanel(RoomSharedAudioSession session) {
    final canControl = _sync.canControl;

    return _wrapDraggable(
      child: Material(
        color: Colors.transparent,
        elevation: 10,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: _panelWidth,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _iconBtn(
                    icon: Icons.power_settings_new_rounded,
                    color: Colors.white70,
                    onTap: canControl
                        ? () {
                            _queue.cancelAutoAdvance();
                            unawaited(_sync.stopAudio());
                          }
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _iconBtn(
                    icon: Icons.close_fullscreen_rounded,
                    color: Colors.white54,
                    onTap: _toggleMinimized,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<List<DeviceAudioEntry>>(
                valueListenable: _queue.queue,
                builder: (context, items, _) {
                  final hasQueue = items.isNotEmpty;
                  return Row(
                    children: [
                      Icon(
                        (_volumeDragging
                                    ? (_dragVolume ??
                                          _sync.effectiveVolume.value)
                                    : _sync.effectiveVolume.value) <=
                                0.01
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      Expanded(child: _buildVolumeSlider(canControl)),
                      const SizedBox(width: 4),
                      _roundBtn(
                        icon: session.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        enabled: canControl,
                        onTap: canControl
                            ? () => unawaited(_sync.togglePlayPause())
                            : null,
                      ),
                      const SizedBox(width: 6),
                      _roundBtn(
                        icon: Icons.skip_next_rounded,
                        enabled: canControl && hasQueue,
                        onTap: canControl && hasQueue
                            ? () => unawaited(_queue.skipToNext())
                            : null,
                      ),
                      const SizedBox(width: 6),
                      _roundBtn(
                        icon: Icons.queue_music_rounded,
                        enabled: widget.onOpenLibrary != null,
                        onTap: widget.onOpenLibrary,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(bool canSet) {
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
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: const Color(0xFF4CAF50),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
            thumbColor: Colors.white,
            disabledActiveTrackColor: const Color(
              0xFF4CAF50,
            ).withValues(alpha: 0.5),
            disabledThumbColor: Colors.white70,
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
        );
      },
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onTap,
        icon: Icon(
          icon,
          color: onTap == null ? color.withValues(alpha: 0.35) : color,
          size: 20,
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return Material(
      color: enabled
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white38,
            size: 20,
          ),
        ),
      ),
    );
  }
}
