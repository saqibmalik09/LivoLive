import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';

class RaveSVGAPlayer extends StatefulWidget {
  final String resUrl;
  final BoxFit fit;
  final bool repeat;
  final VoidCallback? onFinished;
  final VoidCallback? onLoaded;
  final bool autoPlay;
  final double playbackSpeed;

  const RaveSVGAPlayer({
    super.key,
    required this.resUrl,
    this.fit = BoxFit.contain,
    this.repeat = true,
    this.onFinished,
    this.onLoaded,
    this.autoPlay = true,
    this.playbackSpeed = 1.0,
  });

  @override
  State<RaveSVGAPlayer> createState() => RaveSVGAPlayerState();
}

class RaveSVGAPlayerState extends State<RaveSVGAPlayer>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed && !widget.repeat) {
        _controller!.stop();
        widget.onFinished?.call();
      }
    });
    _loadAnimation();
  }

  @override
  void didUpdateWidget(RaveSVGAPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resUrl != widget.resUrl ||
        oldWidget.playbackSpeed != widget.playbackSpeed) {
      _loadAnimation();
    }
  }

  void _applyPlaybackSpeed() {
    final speed = widget.playbackSpeed;
    if (_controller == null || speed <= 0 || speed == 1.0) return;
    final ms = _controller!.duration?.inMilliseconds ?? 0;
    if (ms <= 0) return;
    _controller!.duration = Duration(
      milliseconds: (ms / speed).round().clamp(1, 120000),
    );
  }

  int? _nativeDurationMs;

  void play() {
    final controller = _controller;
    if (controller == null || controller.videoItem == null) return;
    if (widget.repeat) {
      controller.repeat();
    } else {
      controller.forward(from: 0);
    }
  }

  void freeze() {
    _controller?.stop();
  }

  void syncDurationTo(Duration target) {
    final controller = _controller;
    if (controller == null || controller.videoItem == null) return;
    _nativeDurationMs ??= controller.duration?.inMilliseconds;
    controller.duration = target;
  }

  Future<void> _loadAnimation() async {
    try {
      final videoItem;
      if (widget.resUrl.startsWith('assets/')) {
        final data = await rootBundle.load(widget.resUrl);
        videoItem = await SVGAParser.shared.decodeFromBuffer(
          data.buffer.asUint8List(),
        );
      } else {
        videoItem = await SVGAParser.shared.decodeFromURL(widget.resUrl);
      }
      if (mounted && _controller != null) {
        setState(() {
          _controller!.videoItem = videoItem;
          _nativeDurationMs = _controller!.duration?.inMilliseconds;
          _applyPlaybackSpeed();
          if (widget.autoPlay) {
            if (widget.repeat) {
              _controller!.repeat();
            } else {
              _controller!.forward();
            }
          }
        });
        widget.onLoaded?.call();
      } else {
        videoItem.dispose();
      }
    } catch (e) {
      debugPrint('Error loading SVGA: $e');
      if (mounted) {
        widget.onFinished?.call();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _controller!.videoItem == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Colors.transparent,
      child: RepaintBoundary(
        child: SVGAImage(_controller!, fit: widget.fit, clearsAfterStop: true),
      ),
    );
  }
}
