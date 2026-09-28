import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/task/data/task_center_provider.dart';
import 'package:sk_live/features/task/presentation/widgets/task_theme.dart';

class TaskPrizeWheel extends StatefulWidget {
  const TaskPrizeWheel({
    super.key,
    required this.remainingDraws,
    required this.spins,
    required this.onSpin,
    required this.onEmptyDraw,
    this.segments = kTaskWheelSegments,
  });

  final int remainingDraws;
  final List<TaskWheelSpin> spins;
  final Future<Map<String, dynamic>> Function() onSpin;
  final VoidCallback onEmptyDraw;
  final List<TaskWheelSegment> segments;

  @override
  State<TaskPrizeWheel> createState() => _TaskPrizeWheelState();
}

class _TaskPrizeWheelState extends State<TaskPrizeWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _turns = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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
      if (res['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Spin failed'),
              backgroundColor: TaskTheme.magenta,
            ),
          );
        }
        return;
      }

      final segments = widget.segments.isEmpty
          ? kTaskWheelSegments
          : widget.segments;
      final labels = segments.map((s) => s.label).toList();
      final label = res['label']?.toString() ?? labels.first;
      var index = labels.indexOf(label);
      if (index < 0) {
        final coins = (res['reward_coins'] as num?)?.toInt();
        if (coins != null) {
          for (var i = 0; i < segments.length; i++) {
            if (segments[i].label == label) {
              index = i;
              break;
            }
          }
        }
        if (index < 0) index = 0;
      }

      final segment = 1.0 / labels.length;
      final target =
          _turns +
          5 +
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

      if (mounted) {
        final coins = res['reward_coins'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You won $label (${coins ?? 0} coins)!'),
            backgroundColor: TaskTheme.panel,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showRecord() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TaskTheme.deep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String fmt(DateTime d) {
          final local = d.toLocal();
          final m = local.month.toString().padLeft(2, '0');
          final day = local.day.toString().padLeft(2, '0');
          final h = local.hour.toString().padLeft(2, '0');
          final min = local.minute.toString().padLeft(2, '0');
          return '$m/$day $h:$min';
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TaskTheme.gold.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.task_spinRecord,
                  style: const TextStyle(
                    color: TaskTheme.goldLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.spins.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No spins yet. Check in or claim tasks to earn draws.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.spins.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: Colors.white.withValues(alpha: 0.1)),
                      itemBuilder: (_, i) {
                        final s = widget.spins[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            s.rewardLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            fmt(s.createdAt),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            '+${s.rewardCoins}',
                            style: const TextStyle(
                              color: TaskTheme.goldLight,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const size = 268.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        decoration: TaskTheme.goldBorderPanel(radius: 22),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.task_luckyWheel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showRecord,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: TaskTheme.gold.withValues(alpha: 0.7),
                      ),
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      context.l10n.task_record,
                      style: const TextStyle(
                        color: TaskTheme.goldLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Remaining draws : ${widget.remainingDraws}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: TaskTheme.gold.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: TaskTheme.magenta.withValues(alpha: 0.25),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Transform.rotate(
                    angle: _turns * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(size, size),
                      painter: _TaskWheelPainter(
                        segments: widget.segments.isEmpty
                            ? kTaskWheelSegments
                            : widget.segments,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    child: Icon(
                      Icons.diamond,
                      color: TaskTheme.magentaSoft,
                      size: 22,
                    ),
                  ),
                  const Positioned(
                    top: 10,
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: TaskTheme.goldBright,
                      size: 40,
                    ),
                  ),
                  GestureDetector(
                    onTap: _spin,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: TaskTheme.goldButton,
                        border: Border.all(
                          color: TaskTheme.goldBright,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TaskTheme.gold.withValues(alpha: 0.55),
                            blurRadius: 14,
                          ),
                          const BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _busy ? '...' : '${widget.remainingDraws}',
                        style: const TextStyle(
                          color: Color(0xFF3B2500),
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _spin,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: TaskTheme.goldButton,
                  boxShadow: [
                    BoxShadow(
                      color: TaskTheme.gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _busy ? 'Spinning...' : context.l10n.task_go,
                  style: const TextStyle(
                    color: Color(0xFF3B2500),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskWheelPainter extends CustomPainter {
  _TaskWheelPainter({required this.segments});

  final List<TaskWheelSegment> segments;

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
        Rect.fromCircle(center: center, radius: radius - 4),
        start,
        sweep,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = TaskTheme.gold.withValues(alpha: 0.55),
      );

      final mid = start + sweep / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: seg.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
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
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = TaskTheme.gold,
    );
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = TaskTheme.goldBright,
    );
  }

  @override
  bool shouldRepaint(covariant _TaskWheelPainter oldDelegate) => false;
}
