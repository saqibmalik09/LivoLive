import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';

class WeeklyStarTimer extends StatefulWidget {
  const WeeklyStarTimer({super.key, this.endAt});

  final DateTime? endAt;

  @override
  State<WeeklyStarTimer> createState() => _WeeklyStarTimerState();
}

class _WeeklyStarTimerState extends State<WeeklyStarTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recalc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recalc());
  }

  @override
  void didUpdateWidget(covariant WeeklyStarTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endAt != widget.endAt) _recalc();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime get _deadline {
    if (widget.endAt != null) return widget.endAt!.toLocal();
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
  }

  void _recalc() {
    final diff = _deadline.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _remaining.inDays;
    final h = _remaining.inHours.remainder(24);
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _box(d, 'Day'),
        _colon(),
        _box(h, 'Hour'),
        _colon(),
        _box(m, 'Minute'),
        _colon(),
        _box(s, 'Second'),
      ],
    );
  }

  Widget _colon() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _box(int value, String label) {
    final text = value.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(WeeklyStarAssets.timerBox),
              fit: BoxFit.fill,
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
