import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class RoomBonusMultiplierSvgaOverlay extends StatefulWidget {
  final String svgaUrl;
  final double stackOffsetY;
  final VoidCallback onFinished;

  const RoomBonusMultiplierSvgaOverlay({
    super.key,
    required this.svgaUrl,
    this.stackOffsetY = 0,
    required this.onFinished,
  });

  @override
  State<RoomBonusMultiplierSvgaOverlay> createState() =>
      _RoomBonusMultiplierSvgaOverlayState();
}

class _RoomBonusMultiplierSvgaOverlayState
    extends State<RoomBonusMultiplierSvgaOverlay>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4200);

  final GlobalKey<RaveSVGAPlayerState> _svgaKey =
      GlobalKey<RaveSVGAPlayerState>();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _finished = false;
  bool _started = false;
  Timer? _loadWatchdog;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _fade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
    ]).animate(_controller);
    _slide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0.12, 0.18),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 66),
      TweenSequenceItem(
        tween: Tween(
          begin: Offset.zero,
          end: const Offset(-0.04, -0.05),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
    ]).animate(_controller);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishOnce();
    });
    _loadWatchdog = Timer(const Duration(seconds: 3), () {
      if (!mounted || _started) return;
      debugPrint('[BonusMultOverlay] SVGA load timeout — dismissing');
      _finishOnce();
    });
  }

  void _onLoaded() {
    if (!mounted || _started) return;
    _loadWatchdog?.cancel();
    _started = true;
    setState(() {});
    _svgaKey.currentState?.syncDurationTo(_duration);
    _svgaKey.currentState?.play();
    _controller.forward(from: 0);
  }

  void _finishOnce() {
    if (_finished) return;
    _finished = true;
    _loadWatchdog?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _loadWatchdog?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final boxH = (size.height * 0.48).clamp(320.0, 460.0);

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: _started ? 1 : 0,
          child: Transform.translate(
            offset: Offset(0, widget.stackOffsetY - size.height * 0.06),
            child: Center(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: SizedBox(
                    width: size.width,
                    height: boxH,
                    child: Transform.scale(
                      scale: 1.15,
                      child: RaveSVGAPlayer(
                        key: _svgaKey,
                        resUrl: widget.svgaUrl,
                        fit: BoxFit.contain,
                        repeat: false,
                        autoPlay: false,
                        onLoaded: _onLoaded,
                        onFinished: _finishOnce,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
