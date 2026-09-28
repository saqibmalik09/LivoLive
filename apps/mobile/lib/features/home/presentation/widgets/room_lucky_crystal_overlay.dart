import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/number_formatter.dart';

class RoomLuckyCrystalOverlay extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onFinished;

  const RoomLuckyCrystalOverlay({
    super.key,
    required this.data,
    required this.onFinished,
  });

  @override
  State<RoomLuckyCrystalOverlay> createState() =>
      _RoomLuckyCrystalOverlayState();
}

class _RoomLuckyCrystalOverlayState extends State<RoomLuckyCrystalOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _shake;

  static const _goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFBE6), Color(0xFFFFE566), Color(0xFFFFB800)],
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 76),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 12,
      ),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 78),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 12),
    ]).animate(_controller);

    _shake =
        TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 8),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.04), weight: 6),
          TweenSequenceItem(tween: Tween(begin: 0.04, end: -0.04), weight: 6),
          TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.03), weight: 6),
          TweenSequenceItem(tween: Tween(begin: 0.03, end: -0.02), weight: 6),
          TweenSequenceItem(tween: Tween(begin: -0.02, end: 0.0), weight: 6),
          TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 62),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.35, curve: Curves.linear),
          ),
        );

    _controller.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _goldText(String text, {required double fontSize}) {
    return ShaderMask(
      shaderCallback: (bounds) => _goldGradient.createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.5,
          shadows: const [
            Shadow(
              color: Color(0xFF4A3200),
              offset: Offset(0, 2),
              blurRadius: 3,
            ),
            Shadow(
              color: Color(0xCC000000),
              offset: Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tierLabel = widget.data['multiplier_tier']?.toString() ?? 'x1';
    final rewardCoins = (widget.data['reward_coins'] as num?)?.toInt() ?? 0;
    final avatarUrl = widget.data['avatar_url']?.toString();
    final coinsLabel = '${NumberFormatter.format(rewardCoins)} coins';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scale.value,
            child: Transform.rotate(angle: _shake.value, child: child),
          ),
        );
      },
      child: SizedBox(
        width: 240,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              'assets/room/lucky_crystal.webp',
              width: 240,
              height: 260,
              fit: BoxFit.contain,
            ),

            Positioned(
              top: 82,
              left: 0,
              right: 0,
              child: Center(child: _goldText(tierLabel, fontSize: 38)),
            ),

            Positioned(
              bottom: 75,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: Color(0xFF1565C0),
                                child: Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            )
                          : const ColoredBox(
                              color: Color(0xFF1565C0),
                              child: Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: _goldText(coinsLabel, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
