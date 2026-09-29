import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class RoomLuckyProWinOverlay extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final int rewardCoins;
  final double stackOffsetY;
  final VoidCallback onFinished;

  const RoomLuckyProWinOverlay({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.rewardCoins,
    this.stackOffsetY = 0,
    required this.onFinished,
  });

  static const asset = 'assets/room/effects/beaver_fanbi_times.svga';

  @override
  State<RoomLuckyProWinOverlay> createState() => _RoomLuckyProWinOverlayState();
}

class _RoomLuckyProWinOverlayState extends State<RoomLuckyProWinOverlay>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4500);

  final GlobalKey<RaveSVGAPlayerState> _svgaKey =
      GlobalKey<RaveSVGAPlayerState>();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _slideFromBottomRight;
  late final Animation<Offset> _contentSlide;
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
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.86,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 14,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 66),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.94,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);
    _slideFromBottomRight = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.12, 0.18),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 64),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.04, -0.06),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);
    _contentFade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 33),
    ]).animate(_controller);
    _contentSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.1, 0.16),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 14,
      ),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 43),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.06, -0.08),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(const Offset(-0.06, -0.08)),
        weight: 33,
      ),
    ]).animate(_controller);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishOnce();
    });
    _loadWatchdog = Timer(const Duration(seconds: 3), () {
      if (!mounted || _started) return;
      debugPrint('[LuckyProOverlay] SVGA load timeout — dismissing');
      _finishOnce();
    });
  }

  void _onSvgaLoaded() {
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
    final boxW = size.width;
    final boxH = (size.height * 0.52).clamp(360.0, 480.0);

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
                  position: _slideFromBottomRight,
                  child: ScaleTransition(
                    scale: _scale,
                    child: SizedBox(
                      width: boxW,
                      height: boxH,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Transform.scale(
                              scale: 1.2,
                              child: RaveSVGAPlayer(
                                key: _svgaKey,
                                resUrl: RoomLuckyProWinOverlay.asset,
                                fit: BoxFit.contain,
                                repeat: false,
                                autoPlay: false,
                                onLoaded: _onSvgaLoaded,
                              ),
                            ),
                          ),
                          FadeTransition(
                            opacity: _contentFade,
                            child: SlideTransition(
                              position: _contentSlide,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: boxH * 0.10,
                                  left: 24,
                                  right: 24,
                                  bottom: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(0, -8),
                                      child: _Avatar(
                                        avatarUrl: widget.avatarUrl,
                                        // Sized from the ring rather than fixed
                                        // at 56, which left the picture small
                                        // inside a 360-480pt ring. Scales with
                                        // the overlay on any screen size.
                                        size: (boxH * 0.26).clamp(88.0, 120.0),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Transform.translate(
                                      offset: const Offset(0, -6),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '+${NumberFormatter.format(widget.rewardCoins)}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFFFFD54F),
                                              fontSize: 24,
                                              height: 1.1,
                                              fontWeight: FontWeight.w900,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 3,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            widget.username,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19,
                                              height: 1.1,
                                              fontWeight: FontWeight.w800,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black87,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;

  const _Avatar({this.avatarUrl, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD54F), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipOval(child: _buildAvatar()),
    );
  }

  Widget _buildAvatar() {
    // The url arrives raw from message metadata or the users table, so it has
    // to go through MediaUrlUtil like every other avatar in the app. This
    // widget handed it straight to CachedNetworkImage, so any avatar still on
    // the old storage host failed and fell through to the person icon — the
    // placeholder showing inside the win ring instead of the user's picture.
    final resolved = MediaUrlUtil.nullableMediaUrl(avatarUrl);
    if (resolved == null || resolved.isEmpty) return _fallback();
    final transformPx = (size * 3).round();
    return AppNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.cover,
      transformWidth: transformPx,
      transformHeight: transformPx,
      memCacheWidth: transformPx,
      memCacheHeight: transformPx,
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => ColoredBox(
    color: Colors.black45,
    child: Icon(Icons.person, color: Colors.white70, size: size * 0.5),
  );
}
