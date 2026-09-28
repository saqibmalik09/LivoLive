import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/util/big_gift_patti_util.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/patti_room_navigator.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class BigGiftPattiOverlay extends ConsumerStatefulWidget {
  const BigGiftPattiOverlay({
    super.key,
    required this.username,
    required this.giftCoins,
    required this.onFinished,
    this.avatarUrl,
    this.giftName,
    this.roomId,
  });

  final String username;
  final String? avatarUrl;
  final String? giftName;
  final int giftCoins;
  final String? roomId;
  final VoidCallback onFinished;

  @override
  ConsumerState<BigGiftPattiOverlay> createState() =>
      _BigGiftPattiOverlayState();
}

class _BigGiftPattiOverlayState extends ConsumerState<BigGiftPattiOverlay>
    with SingleTickerProviderStateMixin {
  static const _bannerHeight = 100.0;
  static const _displayDuration = Duration(milliseconds: 6500);
  static const _pauseWeight = 8.0;
  static const _enterWeight = 12.0;
  static const _holdWeight = 55.0;
  static const _exitWeight = 25.0;

  static const _profileLeftInset = 74.0;
  static const _textLeftInset = 128.0;
  static const _amountRightInset = 18.0;

  final GlobalKey<RaveSVGAPlayerState> _svgaKey =
      GlobalKey<RaveSVGAPlayerState>();

  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _finished = false;
  bool _svgaReady = false;
  bool _playbackStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _displayDuration);
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(1.0, 0.0)),
        weight: _pauseWeight,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: _enterWeight,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: _holdWeight,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.5, 0.0),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: _exitWeight,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: _pauseWeight,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: _enterWeight,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: _holdWeight),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: _exitWeight,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishOnce();
    });

    Future<void>.delayed(const Duration(seconds: 10), () {
      if (!mounted || _finished) return;
      if (!_playbackStarted) {
        _svgaReady = true;
        _startPlayback();
      }
    });
  }

  void _onSvgaLoaded() {
    if (!mounted || _svgaReady) return;
    setState(() => _svgaReady = true);
    _startPlayback();
  }

  void _startPlayback() {
    if (_playbackStarted || !mounted) return;
    _playbackStarted = true;
    final svga = _svgaKey.currentState;
    svga?.syncDurationTo(_displayDuration);
    svga?.play();
    _controller.forward(from: 0);
  }

  void _finishOnce() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    final coinsLabel = NumberFormatter.format(widget.giftCoins);
    final roomId = widget.roomId;
    final canOpen = roomId != null && roomId.trim().isNotEmpty;
    final liveRoomId = ref.watch(currentLiveRoomIdProvider);
    final allowTap =
        canOpen &&
        (liveRoomId == null || liveRoomId.toString() != roomId.toString());

    final banner = Opacity(
      opacity: _svgaReady ? 1 : 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              RaveSVGAPlayer(
                key: _svgaKey,
                resUrl: BigGiftPattiUtil.svgaAsset,
                fit: BoxFit.contain,
                repeat: false,
                autoPlay: false,
                onLoaded: _onSvgaLoaded,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: _profileLeftInset),
                  child: Transform.translate(
                    offset: const Offset(2, 8),
                    child: _Avatar(avatarUrl: widget.avatarUrl),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: _textLeftInset,
                  right: 110,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            offset: Offset(1, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.giftName != null && widget.giftName!.isNotEmpty
                          ? 'Sent ${widget.giftName}'
                          : 'Sent a big gift',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: _amountRightInset),
                  child: Transform.translate(
                    offset: const Offset(0, 2),
                    child: _PattiAmount3d(label: coinsLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: _bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: banner),
          if (allowTap)
            Positioned(
              left: 72,
              right: 72,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    PattiRoomNavigator.openRoom(context, roomId, ref: ref),
              ),
            ),
        ],
      ),
    );
  }
}

class _PattiAmount3d extends StatelessWidget {
  const _PattiAmount3d({required this.label});

  final String label;

  static const _gold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF8E1),
      Color(0xFFFFE082),
      Color(0xFFFFC107),
      Color(0xFFFF8F00),
    ],
    stops: [0.0, 0.28, 0.62, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.6,
      height: 1,
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(-0.14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 3),
            child: Text(
              label,
              style: baseStyle.copyWith(color: const Color(0xFF4A2C00)),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 1.5),
            child: Text(
              label,
              style: baseStyle.copyWith(color: const Color(0xFF8D5E00)),
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => _gold.createShader(bounds),
            child: Text(
              label,
              style: baseStyle.copyWith(
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0xAAFFFFFF),
                    offset: Offset(0, -1),
                    blurRadius: 0,
                  ),
                  Shadow(
                    color: Color(0x88000000),
                    offset: Offset(0, 1.5),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A2A2A),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: 44,
              height: 44,
              fadeInDuration: Duration.zero,
              placeholder: (_, __) => const ColoredBox(
                color: Color(0xFF3A3A3A),
                child: Icon(Icons.person, color: Colors.white38, size: 22),
              ),
              errorWidget: (_, __, ___) => const ColoredBox(
                color: Color(0xFF3A3A3A),
                child: Icon(Icons.person, color: Colors.white54, size: 22),
              ),
            )
          : const ColoredBox(
              color: Color(0xFF3A3A3A),
              child: Icon(Icons.person, color: Colors.white54, size: 22),
            ),
    );
  }
}
