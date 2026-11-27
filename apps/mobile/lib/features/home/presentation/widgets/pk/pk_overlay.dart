import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/game_overlay_provider.dart';
import 'package:sk_live/core/providers/team_pk_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/number_formatter.dart';

class PkOverlay extends ConsumerStatefulWidget {
  const PkOverlay({
    super.key,
    required this.roomId,
    required this.canManage,
    required this.onRefreshRoom,
    this.playerA,
    this.playerB,
  });

  final String roomId;
  final bool canManage;
  final VoidCallback onRefreshRoom;
  final Map<String, dynamic>? playerA;
  final Map<String, dynamic>? playerB;

  @override
  ConsumerState<PkOverlay> createState() => _PkOverlayState();
}

class _PkOverlayState extends ConsumerState<PkOverlay> {
  Timer? _tickTimer;
  Duration _remaining = Duration.zero;
  bool _stopping = false;
  String? _trackedSessionId;

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _startTimer(RoomPkSession session) {
    if (_trackedSessionId == session.id && _tickTimer != null) return;
    _trackedSessionId = session.id;
    _tickTimer?.cancel();

    void tick() {
      final rem = session.remaining;
      if (mounted) setState(() => _remaining = rem);
      if (rem <= Duration.zero) {
        _tickTimer?.cancel();
        _tickTimer = null;
        TeamPkService.syncSession(widget.roomId);
        widget.onRefreshRoom();
      }
    }

    tick();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _stopTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _trackedSessionId = null;
  }

  Future<void> _stop(RoomPkSession session) async {
    if (_stopping) return;
    setState(() => _stopping = true);
    try {
      await TeamPkService.stopSession(session.id);
      widget.onRefreshRoom();
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _playerName(Map<String, dynamic>? user, String fallback) {
    if (user == null) return fallback;
    return user['username']?.toString() ??
        user['display_name']?.toString() ??
        fallback;
  }

  String _winnerLabel(String? team, String nameA, String nameB) {
    switch (team) {
      case 'a':
        return '$nameA Wins!';
      case 'b':
        return '$nameB Wins!';
      case 'tie':
        return 'Draw!';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(roomPkSessionProvider(widget.roomId));
    final gameOpen = ref.watch(gameOverlayOpenProvider) > 0;

    return sessionAsync.when(
      data: (session) {
        if (session == null || !session.isSolo) {
          _stopTimer();
          return const SizedBox.shrink();
        }

        if (session.isActive && !gameOpen) {
          _startTimer(session);
        } else {
          _stopTimer();
        }

        final nameA = _playerName(widget.playerA, 'Player A');
        final nameB = _playerName(widget.playerB, 'Player B');
        final showWinner = session.isFinished && session.winnerTeam != null;
        final total = session.teamAScore + session.teamBScore;
        final aRatio = total > 0 ? session.teamAScore / total : 0.5;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showWinner)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.95),
                        AppColors.regalOrange.withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _winnerLabel(session.winnerTeam, nameA, nameB),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (session.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDuration(_remaining),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (session.isActive && widget.canManage)
                          TextButton(
                            onPressed: _stopping ? null : () => _stop(session),
                            child: _stopping
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Text(
                                    'Stop',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _playerScore(
                          label: nameA,
                          score: session.teamAScore,
                          color: const Color(0xFFFF5252),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        _playerScore(
                          label: nameB,
                          score: session.teamBScore,
                          color: const Color(0xFF448AFF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            Expanded(
                              flex: (aRatio * 100).round().clamp(1, 99),
                              child: Container(color: const Color(0xFFFF5252)),
                            ),
                            Expanded(
                              flex: ((1 - aRatio) * 100).round().clamp(1, 99),
                              child: Container(color: const Color(0xFF448AFF)),
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
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _playerScore({
    required String label,
    required int score,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            NumberFormatter.format(score),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
