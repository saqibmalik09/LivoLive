import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/task/data/task_center_provider.dart';
import 'package:sk_live/features/task/presentation/widgets/task_theme.dart';

class TaskCheckinHeader extends StatelessWidget {
  const TaskCheckinHeader({
    super.key,
    required this.summary,
    required this.busy,
    required this.onCheckIn,
  });

  final TaskCenterSummary summary;
  final bool busy;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final rewards = summary.dayRewards;
    final streak = summary.streakDay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                color: TaskTheme.gold.withValues(alpha: 0.35),
                size: 64,
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: TaskTheme.goldBright,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.task_checkinBonus,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFFFFF6D0),
                                Color(0xFFF5D76E),
                                Color(0xFFD4AF37),
                                Color(0xFFFFF0B8),
                              ],
                            ).createShader(const Rect.fromLTWH(0, 0, 260, 40)),
                          shadows: TaskTheme.goldTitleShadows,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.star_rounded,
                        color: TaskTheme.goldBright,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          _DayRow(days: const [1, 2, 3, 4], rewards: rewards, streak: streak),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _DayRow(
              days: const [5, 6, 7],
              rewards: rewards,
              streak: streak,
            ),
          ),
          const SizedBox(height: 18),

          _CheckInButton(
            checkedToday: summary.checkedToday,
            busy: busy,
            onCheckIn: onCheckIn,
          ),
          const SizedBox(height: 12),
          Text(
            summary.consecutiveDays > 0
                ? 'You have checked in for ${summary.consecutiveDays} consecutive days. If you miss a check-in, you will start over from day 1.'
                : 'Check in daily to keep your streak. If you miss a day, you start over from day 1.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.days,
    required this.rewards,
    required this.streak,
  });

  final List<int> days;
  final List<int> rewards;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _DayCell(
              day: days[i],
              coins: days[i] - 1 < rewards.length ? rewards[days[i] - 1] : 0,
              checked: streak >= days[i],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.coins,
    required this.checked,
  });

  final int day;
  final int coins;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        gradient: TaskTheme.dayCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: checked
              ? TaskTheme.goldBright
              : TaskTheme.gold.withValues(alpha: 0.75),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: TaskTheme.gold.withValues(alpha: checked ? 0.45 : 0.22),
            blurRadius: checked ? 12 : 8,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'Day $day',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TaskTheme.goldBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (checked)
                const Icon(
                  Icons.check_rounded,
                  color: TaskTheme.goldBright,
                  size: 34,
                )
              else
                const Icon(
                  Icons.monetization_on,
                  color: TaskTheme.goldLight,
                  size: 30,
                ),
              const SizedBox(height: 2),
              Text(
                checked ? '' : '$coins Coins',
                style: const TextStyle(
                  color: TaskTheme.goldBright,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({
    required this.checkedToday,
    required this.busy,
    required this.onCheckIn,
  });

  final bool checkedToday;
  final bool busy;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: checkedToday
            ? null
            : const LinearGradient(
                colors: [
                  Color(0xFFFF8AC8),
                  Color(0xFFE91E8C),
                  Color(0xFFD4AF37),
                ],
              ),
        color: checkedToday ? Colors.white12 : null,
        boxShadow: checkedToday
            ? null
            : [
                BoxShadow(
                  color: TaskTheme.magenta.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: TaskTheme.gold.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(2.2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: checkedToday || busy ? null : onCheckIn,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: checkedToday
                    ? [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                      ]
                    : [
                        const Color(0xFF5A2A95).withValues(alpha: 0.95),
                        const Color(0xFF2C1058).withValues(alpha: 0.98),
                      ],
              ),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: TaskTheme.goldLight,
                      ),
                    )
                  : Text(
                      checkedToday
                          ? context.l10n.task_checkedIn
                          : context.l10n.task_checkIn,
                      style: TextStyle(
                        color: checkedToday ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.4,
                        shadows: checkedToday
                            ? null
                            : [
                                Shadow(
                                  color: TaskTheme.magenta.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
