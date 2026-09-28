import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class RoomMicEmojiOverlayRequest {
  const RoomMicEmojiOverlayRequest({
    required this.seatIndex,
    required this.imageUrl,
    this.svgaUrl,
    this.dedupeKey,
    required this.resolveCenter,
  });

  final int seatIndex;
  final String imageUrl;
  final String? svgaUrl;
  final String? dedupeKey;
  final Offset Function(int seatIndex) resolveCenter;
}

class RoomMicEmojiOverlayController {
  RoomMicEmojiOverlayManagerState? _state;

  void _attach(RoomMicEmojiOverlayManagerState state) => _state = state;

  void _detach(RoomMicEmojiOverlayManagerState state) {
    if (_state == state) _state = null;
  }

  void play(RoomMicEmojiOverlayRequest request) => _state?.play(request);

  bool hasPlayed(String dedupeKey) => _state?.hasPlayed(dedupeKey) ?? false;

  void markPlayed(String dedupeKey) => _state?.markPlayed(dedupeKey);

  void clearAll() => _state?.clearAll();
}

class RoomMicEmojiOverlayManager extends StatefulWidget {
  const RoomMicEmojiOverlayManager({
    super.key,
    required this.controller,
    required this.child,
  });

  final RoomMicEmojiOverlayController controller;
  final Widget child;

  @override
  State<RoomMicEmojiOverlayManager> createState() =>
      RoomMicEmojiOverlayManagerState();
}

class RoomMicEmojiOverlayManagerState extends State<RoomMicEmojiOverlayManager>
    with TickerProviderStateMixin {
  final List<_ActiveOverlay> _active = [];
  final Set<String> _playedKeys = {};

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    for (final item in _active) {
      item.controller.dispose();
    }
    super.dispose();
  }

  bool hasPlayed(String dedupeKey) => _playedKeys.contains(dedupeKey);

  void markPlayed(String dedupeKey) {
    if (dedupeKey.isEmpty) return;
    _playedKeys.add(dedupeKey);
    if (_playedKeys.length > 200) {
      _playedKeys.remove(_playedKeys.first);
    }
  }

  void clearAll() {
    for (final item in _active) {
      item.controller.dispose();
    }
    _active.clear();
    if (mounted) setState(() {});
  }

  void play(RoomMicEmojiOverlayRequest request) {
    if (request.dedupeKey != null && request.dedupeKey!.isNotEmpty) {
      if (_playedKeys.contains(request.dedupeKey)) return;
      markPlayed(request.dedupeKey!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final center = request.resolveCenter(request.seatIndex);
      if (center == Offset.zero) return;

      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      );

      final scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.2,
            end: 1.15,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 35,
        ),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeIn)),
          weight: 20,
        ),
      ]).animate(controller);

      final drift = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0, -36),
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

      final opacity = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
      ]).animate(controller);

      final overlay = _ActiveOverlay(
        center: center,
        imageUrl: request.imageUrl,
        svgaUrl: request.svgaUrl,
        controller: controller,
        scale: scale,
        drift: drift,
        opacity: opacity,
      );

      setState(() => _active.add(overlay));

      controller.forward().whenComplete(() {
        if (!mounted) return;
        overlay.controller.dispose();
        setState(() => _active.remove(overlay));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        ..._active.map((item) => _OverlayBubble(item: item)),
      ],
    );
  }
}

class _ActiveOverlay {
  _ActiveOverlay({
    required this.center,
    required this.imageUrl,
    required this.svgaUrl,
    required this.controller,
    required this.scale,
    required this.drift,
    required this.opacity,
  });

  final Offset center;
  final String imageUrl;
  final String? svgaUrl;
  final AnimationController controller;
  final Animation<double> scale;
  final Animation<Offset> drift;
  final Animation<double> opacity;
}

class _OverlayBubble extends StatelessWidget {
  const _OverlayBubble({required this.item});

  final _ActiveOverlay item;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final svga = item.svgaUrl?.trim() ?? '';
    final useSvga = svga.isNotEmpty && MediaUrlUtil.isSvgaUrl(svga);

    return AnimatedBuilder(
      animation: item.controller,
      builder: (context, child) {
        final pos = item.center + item.drift.value;
        return Positioned(
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: item.opacity.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: item.scale.value,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: useSvga
                      ? RaveSVGAPlayer(
                          resUrl: svga,
                          repeat: false,
                          fit: BoxFit.contain,
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.emoji_emotions, size: 40),
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
