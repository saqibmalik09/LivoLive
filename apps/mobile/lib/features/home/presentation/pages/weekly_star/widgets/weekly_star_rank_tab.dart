import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/weekly_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_rank_board.dart';

class WeeklyStarRankTab extends ConsumerWidget {
  const WeeklyStarRankTab({
    super.key,
    required this.eventId,
    required this.periodKey,
    required this.title,
  });

  final String eventId;
  final String periodKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      weeklyStarTopRankingsProvider((eventId: eventId, periodKey: periodKey)),
    );

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load rankings.\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
      data: (rankings) => WeeklyStarRankBoard(title: title, rankings: rankings),
    );
  }
}
