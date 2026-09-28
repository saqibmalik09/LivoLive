import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/agency_ranking_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/agency_level_nameplate.dart';
import 'package:sk_live/features/home/presentation/widgets/ranking_podium_top3.dart';
import 'package:sk_live/core/providers/ranking_podium_preview_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyRankingScreen extends ConsumerStatefulWidget {
  const AgencyRankingScreen({super.key, this.initialPeriod = 'Week'});

  final String initialPeriod;

  @override
  ConsumerState<AgencyRankingScreen> createState() =>
      _AgencyRankingScreenState();
}

class _AgencyRankingScreenState extends ConsumerState<AgencyRankingScreen> {
  late int _selectedPeriodIndex;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  static const _periods = ['Day', 'Week', 'Month'];

  @override
  void initState() {
    super.initState();
    final idx = _periods.indexOf(widget.initialPeriod);
    _selectedPeriodIndex = idx >= 0 ? idx : 1;
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

  @override
  Widget build(BuildContext context) {
    final period = _periods[_selectedPeriodIndex];
    final rankingsAsync = ref.watch(agencyRankingsProvider(period));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/ranking/podium_agency.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(color: const Color(0xFF2D1B4E)),
          ),
          Container(color: Colors.black.withValues(alpha: 0.5)),
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
                      const Expanded(
                        child: Text(
                          'Agency Rankings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            ref.invalidate(agencyRankingsProvider(period)),
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
                            'No agency rankings yet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      final top3 = rankings
                          .take(3)
                          .map(
                            (m) => RankingPodiumEntry(
                              id: m.agencyId,
                              title: m.name,
                              avatarUrl: m.avatarUrl,
                              rank: m.rank,
                              frameUrl: null,
                            ),
                          )
                          .toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          children: [
                            RankingPodiumTop3(entries: top3),
                            if (top3.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildTop3Nameplates(rankings.take(3).toList()),
                            ],
                            const SizedBox(height: 20),
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

  Widget _buildTop3Nameplates(List<AgencyRankingModel> top3) {
    AgencyRankingModel? at(int i) => i < top3.length ? top3[i] : null;
    final left = at(1);
    final center = at(0);
    final right = at(2);

    Widget plate(AgencyRankingModel? m) {
      if (m == null) return const SizedBox.shrink();
      return Center(
        child: AgencyLevelNameplate(
          agencyName: m.name,
          badgeUrl: m.levelBadgeUrl,
          height: 18,
          maxWidth: 110,
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: plate(left)),
        Expanded(child: plate(center)),
        Expanded(child: plate(right)),
      ],
    );
  }

  Widget _buildRow(AgencyRankingModel agency, int displayRank) {
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
          CircleAvatar(
            radius: 22,
            backgroundImage:
                agency.avatarUrl != null && agency.avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(agency.avatarUrl!)
                : null,
            child: agency.avatarUrl == null || agency.avatarUrl!.isEmpty
                ? const Icon(Icons.business, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agency.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (agency.levelBadgeUrl != null &&
                    agency.levelBadgeUrl!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AgencyLevelNameplate(
                    agencyName: agency.name,
                    badgeUrl: agency.levelBadgeUrl,
                    height: 18,
                    maxWidth: 130,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatScore(agency.score),
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
