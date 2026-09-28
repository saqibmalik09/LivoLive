import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/weekly_room_reward_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_assets.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_history_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_rules_sheet.dart';

class WeeklyRoomRewardSheet extends ConsumerStatefulWidget {
  const WeeklyRoomRewardSheet({super.key, required this.roomId});

  final String roomId;

  static Future<void> show(BuildContext context, {required String roomId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WeeklyRoomRewardSheet(roomId: roomId),
    );
  }

  @override
  ConsumerState<WeeklyRoomRewardSheet> createState() =>
      _WeeklyRoomRewardSheetState();
}

class _WeeklyRoomRewardSheetState extends ConsumerState<WeeklyRoomRewardSheet> {
  Timer? _tick;
  int? _claimingLevel;
  int _displayRemaining = 0;
  String? _boundPeriod;
  final ScrollController _levelsScroll = ScrollController();
  int? _scrolledToHighlight;

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
    _levelsScroll.dispose();
    super.dispose();
  }

  void _syncRemaining(WeeklyRoomRewardProgress progress) {
    if (_boundPeriod != progress.periodKey ||
        (_displayRemaining - progress.remainingSeconds).abs() > 2) {
      _boundPeriod = progress.periodKey;
      _displayRemaining = progress.remainingSeconds;
    }
  }

  void _scrollToHighlight(WeeklyRoomRewardProgress progress) {
    final hl = progress.highlightLevel;
    if (hl == null || progress.levels.isEmpty) return;
    if (_scrolledToHighlight == hl) return;
    final index = progress.levels.indexWhere((l) => l.level == hl);
    if (index <= 0) {
      _scrolledToHighlight = hl;
      return;
    }
    _scrolledToHighlight = hl;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_levelsScroll.hasClients) return;
      final offset = (index * 62.0).clamp(
        0.0,
        _levelsScroll.position.maxScrollExtent,
      );
      _levelsScroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _formatRemainingLocal() {
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

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(
      weeklyRoomRewardProgressProvider(widget.roomId),
    );
    final progress =
        progressAsync.valueOrNull ?? WeeklyRoomRewardProgress.empty();
    _syncRemaining(progress);
    _scrollToHighlight(progress);
    final screen = MediaQuery.sizeOf(context);
    final panelH = screen.height * 0.72;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: screen.width,
        height: panelH,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A2030), Color(0xFF2E1018), Color(0xFF16060B)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0xFFD4A84B), width: 1.4)),
        ),
        child: progressAsync.isLoading && progress.levels.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
              )
            : Column(
                children: [
                  _WeeklyHeroHeader(
                    width: screen.width,
                    height: 132,
                    rules: progress.rules,
                    roomId: widget.roomId,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A1522),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF8B3A4A)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Remaining time in this week: ${_formatRemainingLocal()}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      progress.hasClaimedThisPeriod
                          ? 'Last week claimed ✓ · Now tracking this week (bottom bar). Claim again after this week ends.'
                          : progress.inClaimWindow
                          ? 'Claim only the highest unlocked level from last week (6-day window).'
                          : 'Targets can be claimed only after this week ends.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: progress.hasClaimedThisPeriod
                            ? const Color(0xFFFFD54F).withValues(alpha: 0.95)
                            : progress.inClaimWindow
                            ? Colors.greenAccent.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A101C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Level',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Room Target',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Coin Reward',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      controller: _levelsScroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      itemCount: progress.levels.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final lv = progress.levels[index];
                        return _LevelRow(
                          level: lv,
                          highlighted: progress.highlightLevel == lv.level,
                          claiming: _claimingLevel == lv.level,
                          onClaim: lv.canClaim ? () => _claim(lv.level) : null,
                        );
                      },
                    ),
                  ),
                  if (!progress.isOwner)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        'Only the room owner can claim these rewards.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      2,
                      16,
                      MediaQuery.paddingOf(context).bottom + 10,
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          WeeklyRoomRewardAssets.box,
                          width: 46,
                          height: 46,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF8B3A4A),
                                  ),
                                ),
                                child: Text(
                                  _formatTarget(progress.charm),
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "This Week's Room Owner Entitlement",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _claim(int level) async {
    if (_claimingLevel != null) return;
    setState(() => _claimingLevel = level);
    final res = await WeeklyRoomRewardService.claim(
      roomId: widget.roomId,
      level: level,
    );
    if (!mounted) return;
    setState(() {
      _claimingLevel = null;
      _scrolledToHighlight = null;
    });
    ref.invalidate(weeklyRoomRewardProgressProvider(widget.roomId));
    ref.invalidate(weeklyRoomRewardClaimsProvider(widget.roomId));

    final ok = res['success'] == true;
    final coins = (res['coin_amount'] as num?)?.toInt() ?? 0;
    final message = ok
        ? 'Claimed Lv$level · ${_formatTarget(coins)} coins. This week is now open — keep collecting!'
        : (res['message']?.toString() ?? 'Claim failed');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WeeklyHeroHeader extends StatelessWidget {
  const _WeeklyHeroHeader({
    required this.width,
    required this.height,
    required this.rules,
    required this.roomId,
  });

  final double width;
  final double height;
  final List<String> rules;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.95,
                  colors: [
                    const Color(0xFFFFD54F).withValues(alpha: 0.28),
                    const Color(0xFFFF8F00).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            top: 10,
            bottom: 20,
            width: 70,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFFFD54F).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: 10,
            bottom: 20,
            width: 70,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    const Color(0xFFFFD54F).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.22,
            top: 18,
            width: width * 0.56,
            height: 78,
            child: Opacity(
              opacity: 0.92,
              child: Image.asset(
                WeeklyRoomRewardAssets.box,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: width * 0.33,
            top: 4,
            width: width * 0.34,
            height: 88,
            child: Image.asset(
              WeeklyRoomRewardAssets.cupButton,
              fit: BoxFit.contain,
            ),
          ),
          ..._sparkles(),
          Positioned(
            left: 10,
            top: 10,
            child: GestureDetector(
              onTap: () => WeeklyRoomRewardRulesSheet.show(
                context,
                roomId: roomId,
                rules: rules,
              ),
              child: Image.asset(
                WeeklyRoomRewardAssets.rulesButton,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: () =>
                  WeeklyRoomRewardHistoryScreen.open(context, roomId: roomId),
              child: Image.asset(
                WeeklyRoomRewardAssets.historyButton,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 2,
            child: Text(
              'Weekly Room Rewards',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: width * 0.058,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                height: 1.05,
                letterSpacing: 0.3,
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: const [
                      Color(0xFFFFF8E1),
                      Color(0xFFFFE082),
                      Color(0xFFFFB300),
                      Color(0xFFFF8F00),
                    ],
                  ).createShader(Rect.fromLTWH(0, 0, width * 0.8, 36)),
                shadows: const [
                  Shadow(
                    color: Color(0xCC5D2C00),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sparkles() {
    const dots = <Alignment>[
      Alignment(-0.55, -0.6),
      Alignment(0.5, -0.7),
      Alignment(-0.35, 0.1),
      Alignment(0.42, 0.05),
      Alignment(0.1, -0.85),
    ];
    return [
      for (final a in dots)
        Align(
          alignment: a,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF59D).withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.highlighted,
    required this.claiming,
    required this.onClaim,
  });

  final WeeklyRoomRewardLevelInfo level;
  final bool highlighted;
  final bool claiming;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClaim,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFF4A2810)
                : const Color(0xFF3A101C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFFD4A84B).withValues(alpha: 0.55),
              width: highlighted ? 1.6 : 1,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.22),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${level.level}',
                  style: TextStyle(
                    color: highlighted
                        ? const Color(0xFFFFD54F)
                        : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatTarget(level.requiredPoints),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        _formatTarget(level.coinReward),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (claiming) ...[
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFD54F),
                        ),
                      ),
                    ] else if (level.canClaim) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'Claim',
                        style: TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (level.expired && highlighted) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'Expired',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (highlighted && level.targetReached) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'This week',
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTarget(int value) {
  if (value >= 1000000) {
    final v = value / 1000000.0;
    return '${v.toStringAsFixed(2)}M';
  }
  if (value >= 1000) {
    final v = value / 1000.0;
    return '${v.toStringAsFixed(2)}K';
  }
  return value.toString();
}
