import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sk_live/features/invite_earn/data/invite_earn_config.dart';
import 'package:sk_live/features/invite_earn/presentation/widgets/invite_earn_theme.dart';

class InviteEarnCountdown extends StatefulWidget {
  const InviteEarnCountdown({super.key, required this.endsAt});

  final DateTime endsAt;

  @override
  State<InviteEarnCountdown> createState() => _InviteEarnCountdownState();
}

class _InviteEarnCountdownState extends State<InviteEarnCountdown> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    final diff = widget.endsAt.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
    if (_remaining > Duration.zero) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _tick();
      });
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final mins = _remaining.inMinutes.remainder(60);
    final secs = _remaining.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: InviteEarnTheme.pill(
        fill: InviteEarnTheme.panel.withValues(alpha: 0.85),
      ),
      child: Text(
        '${_two(days)} D  ${_two(hours)} : ${_two(mins)} : ${_two(secs)}',
        style: const TextStyle(
          color: InviteEarnTheme.goldLight,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class InviteLuckyWheel extends StatefulWidget {
  const InviteLuckyWheel({
    super.key,
    required this.remainingDraws,
    required this.onSpin,
    required this.onEmptyDraw,
  });

  final int remainingDraws;
  final Future<Map<String, dynamic>> Function() onSpin;
  final VoidCallback onEmptyDraw;

  @override
  State<InviteLuckyWheel> createState() => _InviteLuckyWheelState();
}

class _InviteLuckyWheelState extends State<InviteLuckyWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _turns = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_busy) return;
    if (widget.remainingDraws <= 0) {
      widget.onEmptyDraw();
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await widget.onSpin();
      if (res['success'] != true) return;

      final labels = InviteEarnConfig.wheelSegments
          .map((s) => s.label)
          .toList();
      final label = res['label']?.toString() ?? labels.first;
      var index = labels.indexOf(label);
      if (index < 0) {
        final coins = (res['reward_coins'] as num?)?.toInt() ?? 0;
        if (coins <= 0) {
          index = labels.indexOf('AGAIN');
        } else if (coins <= 300) {
          index = labels.indexOf('100-300');
        } else if (coins <= 600) {
          index = labels.indexOf('301-600');
        } else {
          index = labels.indexOf('601-1K');
        }
        if (index < 0) index = 0;
      }

      final segment = 1.0 / labels.length;
      final target =
          _turns +
          4 +
          (1 - ((index + 0.5) * segment)) +
          math.Random().nextDouble() * 0.02;

      final anim = Tween<double>(begin: _turns, end: target).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      void listener() => setState(() => _turns = anim.value);
      anim.addListener(listener);
      _controller.reset();
      await _controller.forward();
      anim.removeListener(listener);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 260.0;
    return Column(
      children: [
        Text(
          'Remaining draws : ${widget.remainingDraws}',
          style: const TextStyle(
            color: InviteEarnTheme.cream,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _turns * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(size, size),
                  painter: _WheelPainter(
                    segments: InviteEarnConfig.wheelSegments,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _spin,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: InviteEarnTheme.goldButton,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _busy ? '...' : 'GO',
                    style: const TextStyle(
                      color: Color(0xFF3B2500),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 4,
                child: Icon(
                  Icons.arrow_drop_down,
                  color: InviteEarnTheme.goldLight,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments});

  final List<InviteWheelSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = 2 * math.pi / segments.length;
    var start = -math.pi / 2;

    for (final seg in segments) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color(seg.colorValue);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = InviteEarnTheme.gold.withValues(alpha: 0.7),
      );

      final mid = start + sweep / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelR = radius * 0.62;
      final ox = center.dx + math.cos(mid) * labelR - tp.width / 2;
      final oy = center.dy + math.sin(mid) * labelR - tp.height / 2;
      tp.paint(canvas, Offset(ox, oy));

      start += sweep;
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = InviteEarnTheme.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
