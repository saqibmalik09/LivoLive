import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/game_ranking_provider.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class GameRankingScreen extends ConsumerStatefulWidget {
  const GameRankingScreen({super.key});

  @override
  ConsumerState<GameRankingScreen> createState() => _GameRankingScreenState();
}

class _GameRankingScreenState extends ConsumerState<GameRankingScreen> {
  int _selectedPeriodIndex = 1;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  static const _periods = ['Day', 'Week', 'Month'];

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    late DateTime end;
    if (_selectedPeriodIndex == 0) {
      end = DateTime(now.year, now.month, now.day + 1);
    } else if (_selectedPeriodIndex == 1) {
      end = DateTime(now.year, now.month, now.day + (7 - now.weekday) + 1);
    } else {
      end = DateTime(now.year, now.month + 1, 1);
    }
    if (mounted) setState(() => _remainingTime = end.difference(now));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingTime.inSeconds > 0) {
        if (mounted) {
          setState(() => _remainingTime -= const Duration(seconds: 1));
        }
      } else {
        _calculateRemainingTime();
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00:00';
    final d = duration.inDays;
    final h = duration.inHours.remainder(24).toString().padLeft(2, '0');
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d > 0 ? '${d}d $h:$m:$s' : '$h:$m:$s';
  }

  String _formatScore(int score) {
    if (score >= 1000000) return '${(score / 1000000).toStringAsFixed(2)}M';
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
    return score.toString();
  }

  String _frameForRank(int rank) {
    switch (rank) {
      case 1:
        return 'assets/ranking/rank_1_frame.webp';
      case 2:
        return 'assets/ranking/rank_2_frame.webp';
      default:
        return 'assets/ranking/rank_3_frame.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = _periods[_selectedPeriodIndex];
    final rankingsAsync = ref.watch(gameRankingsProvider(period));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/home/home1.jpeg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFF4A2800)),
          ),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.game_ranking,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            ref.invalidate(gameRankingsProvider(period)),
                        icon: const Icon(Iconsax.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: List.generate(_periods.length, (i) {
                        final active = _selectedPeriodIndex == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedPeriodIndex = i);
                              _calculateRemainingTime();
                            },
                            child: Container(
                              alignment: Alignment.center,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _periods[i],
                                style: TextStyle(
                                  color: active ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ends in ${_formatDuration(_remainingTime)}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: rankingsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    error: (e, _) => asyncErrorWidget(
                      e,
                      style: const TextStyle(color: Colors.white),
                    ),
                    data: (rankings) {
                      if (rankings.isEmpty) {
                        return const Center(
                          child: Text(
                            'No game rankings yet.\nPlay games to climb the board!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  if (rankings.length > 1)
                                    Positioned(
                                      left: 8,
                                      bottom: 0,
                                      child: _buildPodiumUser(
                                        rankings[1],
                                        2,
                                        72,
                                      ),
                                    ),
                                  if (rankings.length > 2)
                                    Positioned(
                                      right: 8,
                                      bottom: 0,
                                      child: _buildPodiumUser(
                                        rankings[2],
                                        3,
                                        72,
                                      ),
                                    ),
                                  if (rankings.isNotEmpty)
                                    Positioned(
                                      top: 0,
                                      child: _buildPodiumUser(
                                        rankings[0],
                                        1,
                                        96,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...rankings
                                .asMap()
                                .entries
                                .where((e) => e.key >= 3)
                                .map((e) => _buildRow(e.value, e.key + 1)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumUser(GiftRankingModel user, int rank, double frameSize) {
    final avatarSize = frameSize * (rank == 1 ? 0.55 : 0.65);
    return GestureDetector(
      onTap: () => NavigationUtils.navigateToProfile(context, ref, user.userId),
      child: SizedBox(
        width: frameSize + 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black26,
                  ),
                  child: ClipOval(
                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 20,
                          ),
                  ),
                ),
                Image.asset(
                  _frameForRank(rank),
                  width: frameSize,
                  height: frameSize,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _formatScore(user.score),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(GiftRankingModel user, int displayRank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$displayRank',
              style: TextStyle(
                color: displayRank <= 3 ? AppColors.gold : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                NavigationUtils.navigateToProfile(context, ref, user.userId),
            child: CircleAvatar(
              radius: 22,
              backgroundImage:
                  user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _formatScore(user.score),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
