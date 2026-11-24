import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Send-again button shown after a gift: gift image in the centre, a ring that
/// drains over [window] and a combo count that pops on every tap. A new [tick]
/// restarts the ring, so the parent never rebuilds the room to animate it.
class RoomGiftComboButton extends StatefulWidget {
  const RoomGiftComboButton({
    super.key,
    required this.giftIcon,
    required this.count,
    required this.tick,
    required this.window,
    required this.onTap,
    this.onLongPress,
  });

  final String giftIcon;
  final int count;
  final int tick;
  final Duration window;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<RoomGiftComboButton> createState() => _RoomGiftComboButtonState();
}

class _RoomGiftComboButtonState extends State<RoomGiftComboButton>
    with TickerProviderStateMixin {
  static const double _size = 74;

  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: widget.window,
  )..forward();

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 35),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.18,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(RoomGiftComboButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window != widget.window) {
      _ring.duration = widget.window;
    }
    if (oldWidget.tick != widget.tick) {
      _ring.forward(from: 0);
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    _pop.dispose();
    super.dispose();
  }

  Widget _giftImage() {
    const fallback = Icon(Icons.card_giftcard, color: Colors.white, size: 30);
    if (widget.giftIcon.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: widget.giftIcon,
      width: 42,
      height: 42,
      memCacheWidth: 128,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      errorWidget: (_, _, _) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final windowMs = widget.window.inMilliseconds;
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _popScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${widget.count}',
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: _size,
                height: _size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: _size - 8,
                      height: _size - 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFB347), Color(0xFFFF4D8D)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _giftImage(),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ComboRingPainter(progress: _ring),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              AnimatedBuilder(
                animation: _ring,
                builder: (context, _) {
                  final leftMs = ((1 - _ring.value) * windowMs).ceil();
                  final seconds = (leftMs / 1000).toStringAsFixed(1);
                  return Text(
                    '${seconds}s',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboRingPainter extends CustomPainter {
  _ComboRingPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  static const double _stroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final remaining = 1 - progress.value;
    if (remaining <= 0) return;
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _stroke;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * remaining, false, arc);
  }

  @override
  bool shouldRepaint(_ComboRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
