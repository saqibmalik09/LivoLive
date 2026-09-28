import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/task/services/daily_signin_service.dart';

class DailySignInPopup extends StatefulWidget {
  const DailySignInPopup({
    super.key,
    required this.streakDays,
    required this.days,
    required this.onSignedIn,
    required this.onOpenTasks,
  });

  final int streakDays;
  final List<DailySignInDayReward> days;
  final VoidCallback onSignedIn;
  final VoidCallback onOpenTasks;

  static Future<void> show(
    BuildContext context, {
    required int streakDays,
    required List<DailySignInDayReward> days,
    required VoidCallback onOpenTasks,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.signin_dailyTitle,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim, secondary) {
        return DailySignInPopup(
          streakDays: streakDays,
          days: days,
          onSignedIn: () => Navigator.of(ctx).pop(),
          onOpenTasks: () {
            Navigator.of(ctx).pop();
            onOpenTasks();
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }

  @override
  State<DailySignInPopup> createState() => _DailySignInPopupState();
}

class _DailySignInPopupState extends State<DailySignInPopup> {
  late int _streak;
  bool _busy = false;
  bool _done = false;
  String? _toast;

  @override
  void initState() {
    super.initState();
    _streak = widget.streakDays;
  }

  Future<void> _signIn() async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _toast = null;
    });
    final result = await DailySignInService.performSignIn();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _done = true;
        _streak = result.streak;
        _toast = result.message;
      } else {
        _toast = result.message;
      }
    });
    if (result.ok) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) widget.onSignedIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(0, 320).toDouble();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width - 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 28),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EE),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 72),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.signin_dailyTitle,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5A2A12),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.signin_winBig,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFC0392B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RewardGrid(streak: _streak, days: widget.days),
                    const SizedBox(height: 8),
                    Text(
                      _streak <= 0
                          ? 'You have signed in for 0 day'
                          : 'You have signed in for $_streak day${_streak == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF8A7A6A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_toast != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _toast!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _done
                              ? const Color(0xFF1B7A3D)
                              : const Color(0xFFC0392B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _SignInButton(busy: _busy, done: _done, onTap: _signIn),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: widget.onOpenTasks,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      child: Text(
                        'View all tasks →',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5A2B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                top: -4,
                right: 2,
                child: Image.asset(
                  'assets/rewards/daily_signin_gift.webp',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stackTrace) => const Icon(
                    Icons.card_giftcard_rounded,
                    size: 64,
                    color: Color(0xFFE8A317),
                  ),
                ),
              ),

              Positioned(
                top: 32,
                right: 4,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await DailySignInService.markPopupShown();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9A8A7A),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardGrid extends StatelessWidget {
  const _RewardGrid({required this.streak, required this.days});

  final int streak;
  final List<DailySignInDayReward> days;

  DailySignInDayReward _day(int n) {
    return days.firstWhere(
      (d) => d.dayNumber == n,
      orElse: () => DailySignInDayReward(
        dayNumber: n,
        rewardType: 'coins',
        coinAmount: 0,
        label: 'Day $n',
      ),
    );
  }

  Widget _card(int n, {bool wide = false}) {
    final reward = _day(n);
    return _DayCard(
      reward: reward,
      claimed: streak >= n,
      today: streak + 1 == n || (streak == 0 && n == 1),
      wide: wide,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(child: _card(i)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 4; i <= 6; i++) ...[
              if (i > 4) const SizedBox(width: 6),
              Expanded(child: _card(i)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        _card(7, wide: true),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.reward,
    required this.claimed,
    required this.today,
    this.wide = false,
  });

  final DailySignInDayReward reward;
  final bool claimed;
  final bool today;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final amountText = reward.isAsset ? '×1' : '×${reward.coinAmount}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: wide ? 64 : 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: claimed
              ? const [Color(0xFFFFE7A8), Color(0xFFFFD06A)]
              : const [Color(0xFFFFF3D4), Color(0xFFFFE6A8)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: today
              ? const Color(0xFFE67E22)
              : claimed
              ? const Color(0xFFD4A017)
              : const Color(0xFFE8D4A8),
          width: today ? 1.6 : 1,
        ),
        boxShadow: today
            ? [
                BoxShadow(
                  color: const Color(0xFFE67E22).withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          if (wide)
            Row(
              children: [
                const SizedBox(width: 14),
                _RewardIcon(reward: reward),
                const SizedBox(width: 10),
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '${reward.dayNumber} DAY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF5A2A12),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                const Spacer(),
                _RewardIcon(reward: reward),
                const SizedBox(height: 2),
                Text(
                  amountText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${reward.dayNumber} DAY',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF5A2A12),
                    ),
                  ),
                ),
              ],
            ),
          if (claimed)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  color: Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardIcon extends StatelessWidget {
  const _RewardIcon({required this.reward});

  final DailySignInDayReward reward;

  @override
  Widget build(BuildContext context) {
    final url = reward.imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    if (!reward.isAsset) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
              blurRadius: 5,
            ),
          ],
        ),
        child: const Icon(
          Icons.monetization_on_rounded,
          color: Colors.white,
          size: 18,
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)],
        ),
      ),
      child: const Icon(
        Icons.card_giftcard_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.busy,
    required this.done,
    required this.onTap,
  });

  final bool busy;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy || done ? null : onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: done
                ? const [Color(0xFF81C784), Color(0xFF388E3C)]
                : const [
                    Color(0xFFFFF59D),
                    Color(0xFFFFB300),
                    Color(0xFFFF6F00),
                    Color(0xFFE65100),
                  ],
            stops: done ? null : const [0.0, 0.35, 0.7, 1.0],
          ),
          border: Border.all(color: const Color(0xFFFFE082), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6F00).withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                done ? 'Signed In' : 'Sign In',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                  shadows: const [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
