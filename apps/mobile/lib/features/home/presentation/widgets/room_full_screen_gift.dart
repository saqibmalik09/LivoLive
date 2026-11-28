import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/gift_video_player.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

/// The full-screen gift animation, with a fallback for assets that never come.
///
/// A gift whose SVGA fails to decode (bad upload, dead URL, 2G phone) used to
/// leave the room with nothing at all, which is why some gifts "did not play".
/// The icon pops instead so the gift still reads, and playback is reported as
/// finished either way so the queued gift behind it is not stuck.
class RoomFullScreenGift extends StatefulWidget {
  const RoomFullScreenGift({
    super.key,
    required this.svgaUrl,
    required this.onFinished,
    this.fallbackIconUrl = '',
    this.muted = false,
  });

  /// SVGA or MP4; an MP4 plays with its sound unless [muted].
  final String svgaUrl;
  final String fallbackIconUrl;
  final VoidCallback onFinished;

  /// The room speaker is off, so the MP4 plays silently.
  final bool muted;

  /// How long the SVGA has to start before the icon stands in for it.
  static const Duration decodeDeadline = Duration(milliseconds: 1600);

  /// How long the icon fallback stays on screen once the SVGA has failed.
  static const Duration fallbackVisibleFor = Duration(milliseconds: 1100);

  /// A slow first download keeps the icon up and waits this long in total
  /// for the SVGA, then plays it. Closing at the decode deadline cut off
  /// every first send of a gift that was not cached yet.
  static const Duration slowLoadDeadline = Duration(seconds: 25);

  @override
  State<RoomFullScreenGift> createState() => _RoomFullScreenGiftState();
}

class _RoomFullScreenGiftState extends State<RoomFullScreenGift> {
  Timer? _deadlineTimer;
  Timer? _fallbackTimer;
  bool _svgaStarted = false;
  bool _showFallback = false;
  bool _reportedFinished = false;

  @override
  void initState() {
    super.initState();
    _deadlineTimer = Timer(RoomFullScreenGift.decodeDeadline, () {
      if (!mounted || _svgaStarted) return;
      _startFallback(
        visibleFor:
            RoomFullScreenGift.slowLoadDeadline -
            RoomFullScreenGift.decodeDeadline,
      );
    });
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  final Stopwatch _loadWatch = Stopwatch()..start();

  void _onSvgaLoaded() {
    debugPrint(
      '[gift_fx] fullscreen loaded after ${_loadWatch.elapsedMilliseconds}ms '
      '${_reportedFinished ? '(too late, already closed) ' : ''}'
      '${widget.svgaUrl}',
    );
    if (_reportedFinished) return;
    _svgaStarted = true;
    _deadlineTimer?.cancel();
    _fallbackTimer?.cancel();
    if (_showFallback && mounted) setState(() => _showFallback = false);
  }

  void _onSvgaFinished() {
    // A decode failure also lands here, before the animation ever started.
    if (_svgaStarted) {
      _finish();
      return;
    }
    debugPrint(
      '[gift_fx] fullscreen FAILED after ${_loadWatch.elapsedMilliseconds}ms '
      '${widget.svgaUrl}',
    );
    _startFallback();
  }

  void _startFallback({
    Duration visibleFor = RoomFullScreenGift.fallbackVisibleFor,
  }) {
    if (_reportedFinished) return;
    _deadlineTimer?.cancel();
    final slow = visibleFor > RoomFullScreenGift.fallbackVisibleFor;
    if (widget.fallbackIconUrl.isEmpty && !slow) {
      _finish();
      return;
    }
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(visibleFor, _finish);
    if (!mounted) return;
    setState(() => _showFallback = true);
  }

  void _finish() {
    if (_reportedFinished) return;
    _reportedFinished = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (MediaUrlUtil.isVideoUrl(widget.svgaUrl))
          GiftVideoPlayer(
            url: widget.svgaUrl,
            muted: widget.muted,
            repeat: false,
            fit: BoxFit.cover,
            streamIfNotCached: true,
            onLoaded: _onSvgaLoaded,
            onFinished: _onSvgaFinished,
          )
        else
          RaveSVGAPlayer(
            resUrl: widget.svgaUrl,
            repeat: false,
            fit: BoxFit.cover,
            playbackSpeed: 1.5,
            filterQuality: FilterQuality.medium,
            onLoaded: _onSvgaLoaded,
            onFinished: _onSvgaFinished,
          ),
        if (_showFallback && widget.fallbackIconUrl.isNotEmpty)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: CachedNetworkImage(
                imageUrl: widget.fallbackIconUrl,
                width: shortest * 0.45,
                height: shortest * 0.45,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}
