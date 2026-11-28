import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sk_live/core/util/gift_video_cache.dart';
import 'package:video_player/video_player.dart';

/// Plays an MP4 gift animation over the room.
///
/// Gift MP4s are rendered on black; [keyOutBlack] turns brightness into
/// opacity so the black disappears and only the effect shows over the room.
/// Same callbacks as `RaveSVGAPlayer`, so callers can swap one for the other:
/// [onLoaded] once the first frame can be drawn, [onFinished] at the end of a
/// non-repeating play or on any failure.
class GiftVideoPlayer extends StatefulWidget {
  const GiftVideoPlayer({
    super.key,
    required this.url,
    this.muted = true,
    this.repeat = false,
    this.fit = BoxFit.contain,
    this.keyOutBlack = true,
    this.streamIfNotCached = false,
    this.onLoaded,
    this.onFinished,
  });

  final String url;
  final bool muted;
  final bool repeat;
  final BoxFit fit;
  final bool keyOutBlack;

  /// Start playing from the network instead of waiting for the whole file;
  /// the disk copy still downloads for the next play.
  final bool streamIfNotCached;
  final VoidCallback? onLoaded;
  final VoidCallback? onFinished;

  @override
  State<GiftVideoPlayer> createState() => _GiftVideoPlayerState();
}

class _GiftVideoPlayerState extends State<GiftVideoPlayer> {
  /// Hardware decoders are few on a cheap phone; muted centre previews past
  /// this keep their still icon instead of starving the full-screen gift.
  static const int _maxMutedPlayers = 3;
  static int _activeMuted = 0;

  /// Alpha from brightness: pure black is fully transparent, mid tones
  /// partly, anything bright stays opaque.
  static const ColorFilter _blackKey = ColorFilter.matrix(<double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0.9, 1.3, 0.6, 0, 0, //
  ]);

  VideoPlayerController? _controller;
  bool _countedMuted = false;
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (widget.muted) {
      if (_activeMuted >= _maxMutedPlayers) return;
      _activeMuted++;
      _countedMuted = true;
    }
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      // Never take audio focus from the voice room.
      final options = VideoPlayerOptions(mixWithOthers: true);
      final cached = GiftVideoCache.readyFile(widget.url);
      final VideoPlayerController controller;
      if (cached != null) {
        controller = VideoPlayerController.file(
          cached,
          videoPlayerOptions: options,
        );
      } else if (widget.streamIfNotCached) {
        unawaited(
          GiftVideoCache.file(widget.url).then<void>((_) {}, onError: (_) {}),
        );
        controller = VideoPlayerController.networkUrl(
          Uri.parse(GiftVideoCache.resolvedUrl(widget.url)),
          videoPlayerOptions: options,
        );
      } else {
        final file = await GiftVideoCache.file(widget.url);
        if (!mounted) return;
        controller = VideoPlayerController.file(
          file,
          videoPlayerOptions: options,
        );
      }
      _controller = controller;
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      GiftVideoCache.rememberDuration(widget.url, controller.value.duration);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.setLooping(widget.repeat);
      if (!widget.repeat) controller.addListener(_watchEnd);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
      widget.onLoaded?.call();
    } catch (e) {
      debugPrint('[gift_video] play failed ${widget.url}: $e');
      _finish();
    }
  }

  void _watchEnd() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    if (value.hasError) {
      _finish();
      return;
    }
    final duration = value.duration;
    if (duration > Duration.zero &&
        value.position >= duration - const Duration(milliseconds: 80) &&
        !value.isPlaying) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    if (mounted) widget.onFinished?.call();
  }

  @override
  void didUpdateWidget(GiftVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      unawaited(_controller?.setVolume(widget.muted ? 0 : 1));
    }
  }

  @override
  void dispose() {
    if (_countedMuted) _activeMuted--;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_watchEnd);
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = controller.value.size;
    Widget video = FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width <= 0 ? 1 : size.width,
        height: size.height <= 0 ? 1 : size.height,
        child: VideoPlayer(controller),
      ),
    );
    if (widget.keyOutBlack) {
      video = ColorFiltered(colorFilter: _blackKey, child: video);
    }
    return RepaintBoundary(child: video);
  }
}
