import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';

class GameStarHistoryTab extends ConsumerWidget {
  const GameStarHistoryTab({super.key, required this.eventId, this.gameId});

  final String eventId;
  final String? gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      gameStarHistoryProvider((eventId: eventId, gameId: gameId)),
    );

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load history.\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
      data: (weeks) {
        if (weeks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No history yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Column(
            children: [
              for (final week in weeks) ...[
                _HistoryCard(week: week),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.week});

  final GameStarHistoryWeek week;

  static const double _aspect = 479 / 592;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 24;
    final h = w / _aspect;
    final label = _weekLabel(week);

    final t1 = (left: w * 0.5 - (w * 0.14), top: h * 0.205, size: w * 0.28);
    final t2 = (left: w * 0.08, top: h * 0.525, size: w * 0.22);
    final t3 = (left: w * 0.70, top: h * 0.525, size: w * 0.22);

    final u1 = week.top3.isNotEmpty ? week.top3[0] : null;
    final u2 = week.top3.length > 1 ? week.top3[1] : null;
    final u3 = week.top3.length > 2 ? week.top3[2] : null;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          _avatar(user: u1, left: t1.left, top: t1.top, size: t1.size),
          _avatar(user: u2, left: t2.left, top: t2.top, size: t2.size),
          _avatar(user: u3, left: t3.left, top: t3.top, size: t3.size),

          Positioned.fill(
            child: Image.asset(GameStarAssets.historyCard, fit: BoxFit.fill),
          ),

          Positioned(
            left: w * 0.22,
            right: w * 0.22,
            top: h * 0.055,
            height: h * 0.055,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),

          _meta(
            user: u1,
            left: t1.left,
            top: t1.top + t1.size * 1.18,
            size: t1.size,
          ),
          _meta(
            user: u2,
            left: t2.left,
            top: t2.top + t2.size * 1.18,
            size: t2.size,
          ),
          _meta(
            user: u3,
            left: t3.left,
            top: t3.top + t3.size * 1.18,
            size: t3.size,
          ),
        ],
      ),
    );
  }

  Widget _avatar({
    required GameStarUserRank? user,
    required double left,
    required double top,
    required double size,
  }) {
    final avatar = size * 0.7;
    return Positioned(
      left: left + (size - avatar) / 2,
      top: top + size * 0.12,
      width: avatar,
      height: avatar,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
        ),
        child: ClipOval(
          child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: user.avatarUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.person, color: Colors.white54),
                )
              : const Icon(Icons.person, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _meta({
    required GameStarUserRank? user,
    required double left,
    required double top,
    required double size,
  }) {
    return Positioned(
      left: left - size * 0.08,
      top: top,
      width: size * 1.16,
      child: Column(
        children: [
          Text(
            user?.displayName ?? '--',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: (size * 0.13).clamp(9.0, 12.0),
              shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
            ),
          ),
          Text(
            user != null ? formatGameStarScore(user.score) : '0',
            style: TextStyle(
              color: const Color(0xFFFFE082),
              fontWeight: FontWeight.w900,
              fontSize: (size * 0.12).clamp(9.0, 11.0),
              shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }

  String _weekLabel(GameStarHistoryWeek week) {
    if (week.periodStart != null) {
      final s = week.periodStart!.toLocal();
      final e = week.periodEnd?.toLocal() ?? s.add(const Duration(days: 6));
      return '${s.month}/${s.day} - ${e.month}/${e.day}';
    }
    return week.periodKey;
  }
}
