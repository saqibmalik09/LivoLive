import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/weekly_room_reward_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_history_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_rules_sheet.dart';
import 'package:sk_live/features/task/presentation/widgets/task_theme.dart';

class RoomRewardPage extends ConsumerStatefulWidget {
  const RoomRewardPage({super.key, required this.roomId});

  final String roomId;

  static Future<void> open(BuildContext context, {required String roomId}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RoomRewardPage(roomId: roomId)));
  }

  @override
  ConsumerState<RoomRewardPage> createState() => _RoomRewardPageState();
}

class _RoomRewardPageState extends ConsumerState<RoomRewardPage> {
  Timer? _tick;
  int? _claimingLevel;
  int _displayRemaining = 0;
  String? _boundPeriod;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _displayRemaining <= 0) return;
      setState(() => _displayRemaining -= 1);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncRemaining(WeeklyRoomRewardProgress progress) {
    if (_boundPeriod != progress.periodKey ||
        (_displayRemaining - progress.remainingSeconds).abs() > 2) {
      _boundPeriod = progress.periodKey;
      _displayRemaining = progress.remainingSeconds;
    }
  }

  String _formatRemaining() {
    var sec = _displayRemaining;
    if (sec < 0) sec = 0;
    final days = sec ~/ 86400;
    final hours = (sec % 86400) ~/ 3600;
    final mins = (sec % 3600) ~/ 60;
    final secs = sec % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    if (days > 0) return '${days}d $hh:$mm:$ss';
    return '$hh:$mm:$ss';
  }

  Future<void> _claim(int level) async {
    if (_claimingLevel != null) return;
    setState(() => _claimingLevel = level);
    final res = await WeeklyRoomRewardService.claim(
      roomId: widget.roomId,
      level: level,
    );
    if (!mounted) return;
    setState(() => _claimingLevel = null);
    ref.invalidate(weeklyRoomRewardProgressProvider(widget.roomId));
    ref.invalidate(weeklyRoomRewardClaimsProvider(widget.roomId));

    final ok = res['success'] == true;
    final msg =
        res['message']?.toString() ??
        (ok
            ? context.l10n.reward_claimedSuccessfully
            : context.l10n.reward_claimFailed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? TaskTheme.panel : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(
      weeklyRoomRewardProgressProvider(widget.roomId),
    );
    final progress =
        progressAsync.valueOrNull ?? WeeklyRoomRewardProgress.empty();
    _syncRemaining(progress);
    final focus = progress.currentWeekFocusLevel;
    final required = focus?.requiredPoints ?? 1;
    final ratio = required > 0
        ? (progress.charm / required).clamp(0.0, 1.0)
        : 0.0;
    final claimable = progress.claimableLevel;

    return Scaffold(
      backgroundColor: TaskTheme.deep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: TaskTheme.pageBg),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: TaskStarfieldPainter())),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Row(
                    children: [
                      _GoldCircleButton(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.reward_roomTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: TaskTheme.goldBright,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.4,
                            shadows: [
                              Shadow(color: Color(0xE6D4AF37), blurRadius: 12),
                              Shadow(color: Color(0x73E91E8C), blurRadius: 22),
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _GoldCircleButton(
                        icon: Icons.help_outline_rounded,
                        onTap: () => WeeklyRoomRewardRulesSheet.show(
                          context,
                          roomId: widget.roomId,
                          rules: progress.rules,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _GoldCircleButton(
                        icon: Icons.history_rounded,
                        onTap: () => WeeklyRoomRewardHistoryScreen.open(
                          context,
                          roomId: widget.roomId,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: progressAsync.isLoading && progress.levels.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: TaskTheme.goldLight,
                          ),
                        )
                      : RefreshIndicator(
                          color: TaskTheme.goldLight,
                          backgroundColor: TaskTheme.panel,
                          onRefresh: () async {
                            ref.invalidate(
                              weeklyRoomRewardProgressProvider(widget.roomId),
                            );
                            await ref.read(
                              weeklyRoomRewardProgressProvider(
                                widget.roomId,
                              ).future,
                            );
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: TaskTheme.gold.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 28,
                                        spreadRadius: 2,
                                      ),
                                      BoxShadow(
                                        color: TaskTheme.magenta.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 36,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/profile/room_reward.webp',
                                    width: 118,
                                    height: 118,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                progress.isOwner
                                    ? context.l10n.reward_yourRoomWeekly
                                    : context.l10n.reward_roomOwnerRewards,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: TaskTheme.cream.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: TaskTheme.goldBorderPanel(
                                  radius: 22,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          context.l10n.reward_thisWeek,
                                          style: const TextStyle(
                                            color: TaskTheme.goldLight,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            gradient: TaskTheme.goldButton,
                                            boxShadow: [
                                              BoxShadow(
                                                color: TaskTheme.gold
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            _formatRemaining(),
                                            style: const TextStyle(
                                              color: Color(0xFF3B2500),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      '${NumberFormatter.format(progress.charm)} / ${NumberFormatter.format(required)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      focus == null
                                          ? context.l10n.reward_noLevels
                                          : 'Toward Lv${focus.level}',
                                      style: TextStyle(
                                        color: TaskTheme.cream.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      height: 14,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        border: Border.all(
                                          color: TaskTheme.gold.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.35,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: Stack(
                                          children: [
                                            FractionallySizedBox(
                                              widthFactor: ratio,
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFFFFF0B8),
                                                      Color(0xFFE8B923),
                                                      Color(0xFFFF6BB5),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (progress.inClaimWindow) ...[
                                      const SizedBox(height: 14),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          gradient: claimable != null
                                              ? TaskTheme.claimButton
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFF4B2588),
                                                    Color(0xFF2C1058),
                                                  ],
                                                ),
                                          border: Border.all(
                                            color: TaskTheme.gold.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (claimable != null
                                                          ? TaskTheme.magenta
                                                          : Colors.black)
                                                      .withValues(alpha: 0.35),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          claimable != null
                                              ? 'Claim window open — Lv${claimable.level} ready'
                                              : progress.hasClaimedThisPeriod
                                              ? context
                                                    .l10n
                                                    .reward_lastWeekClaimed
                                              : 'Claim window open — no unlock yet',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                context.l10n.reward_levels,
                                style: TextStyle(
                                  color: TaskTheme.goldBright,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  shadows: TaskTheme.goldTitleShadows,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...progress.levels.map((level) {
                                final highlight =
                                    progress.highlightLevel == level.level;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _LevelCard3d(
                                    level: level,
                                    highlight: highlight,
                                    claiming: _claimingLevel == level.level,
                                    onClaim: level.canClaim
                                        ? () => _claim(level.level)
                                        : null,
                                  ),
                                );
                              }),
                              if (progress.levels.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: TaskTheme.goldBorderPanel(
                                    radius: 18,
                                  ),
                                  child: Text(
                                    context.l10n.reward_noRoomLevelsAdmin,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: TaskTheme.cream.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldCircleButton extends StatelessWidget {
  const _GoldCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: TaskTheme.goldButton,
          boxShadow: [
            BoxShadow(
              color: TaskTheme.gold.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: TaskTheme.goldBright.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        child: Icon(icon, color: const Color(0xFF3B2500), size: 18),
      ),
    );
  }
}

class _LevelCard3d extends StatelessWidget {
  const _LevelCard3d({
    required this.level,
    required this.highlight,
    required this.claiming,
    this.onClaim,
  });

  final WeeklyRoomRewardLevelInfo level;
  final bool highlight;
  final bool claiming;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final isAsset = level.rewardType == 'shop_item';
    final rewardLabel = isAsset
        ? (level.title.isNotEmpty
              ? level.title
              : context.l10n.reward_assetReward)
        : '${NumberFormatter.format(level.coinReward)} coins';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5A2A98),
                  Color(0xFF3A1A72),
                  Color(0xFF2C1058),
                ],
              )
            : TaskTheme.dayCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? TaskTheme.goldBright
              : TaskTheme.gold.withValues(alpha: 0.55),
          width: highlight ? 2.2 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: (highlight ? TaskTheme.gold : Colors.black).withValues(
              alpha: highlight ? 0.4 : 0.35,
            ),
            blurRadius: highlight ? 16 : 10,
            offset: const Offset(0, 6),
          ),
          if (highlight)
            BoxShadow(
              color: TaskTheme.magenta.withValues(alpha: 0.22),
              blurRadius: 18,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF5A2A98), Color(0xFF2C1058)],
              ),
              border: Border.all(
                color: TaskTheme.gold.withValues(alpha: 0.7),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isAsset && level.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: level.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Icon(
                      Icons.card_giftcard,
                      color: TaskTheme.goldLight,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/rewards/lucky-bag/coin-1.webp',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.monetization_on,
                        color: TaskTheme.goldLight,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lv${level.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target ${NumberFormatter.format(level.requiredPoints)}',
                  style: TextStyle(
                    color: TaskTheme.cream.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rewardLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TaskTheme.goldBright,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onClaim != null)
            _Claim3dButton(busy: claiming, onTap: onClaim!)
          else if (level.claimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Text(
                context.l10n.common_claimed,
                style: const TextStyle(
                  color: Color(0xFFA5D6A7),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            )
          else if (level.targetReached)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: TaskTheme.goldButton,
                boxShadow: [
                  BoxShadow(
                    color: TaskTheme.gold.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF3B2500),
                size: 20,
              ),
            )
          else
            Icon(
              Icons.lock_outline_rounded,
              color: TaskTheme.cream.withValues(alpha: 0.35),
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _Claim3dButton extends StatelessWidget {
  const _Claim3dButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: TaskTheme.claimButton,
          border: Border.all(
            color: const Color(0xFFFFB6D9).withValues(alpha: 0.85),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: TaskTheme.magenta.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                context.l10n.common_claim,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
