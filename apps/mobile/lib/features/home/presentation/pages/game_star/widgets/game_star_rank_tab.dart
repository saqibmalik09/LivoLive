import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';

class GameStarRankTab extends ConsumerWidget {
  const GameStarRankTab({super.key, required this.eventId, this.gameId});

  final String eventId;
  final String? gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      gameStarTopRankingsProvider((
        eventId: eventId,
        periodKey: 'current',
        gameId: gameId,
      )),
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
      data: (rankings) => GameStarRankBoard(rankings: rankings),
    );
  }
}

class GameStarRankBoard extends StatelessWidget {
  const GameStarRankBoard({super.key, required this.rankings});

  final List<GameStarUserRank> rankings;

  static const double _aspect = 225 / 600;

  GameStarUserRank? get _t1 => rankings.isNotEmpty ? rankings.first : null;
  GameStarUserRank? get _t2 => rankings.length > 1 ? rankings[1] : null;
  GameStarUserRank? get _t3 => rankings.length > 2 ? rankings[2] : null;
  List<GameStarUserRank> get _rest =>
      rankings.length > 3 ? rankings.sublist(3) : const [];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 16;
    final h = w / _aspect;

    final t1 = (left: w * 0.5 - (w * 0.13), top: h * 0.095, size: w * 0.26);
    final t2 = (left: w * 0.115, top: h * 0.265, size: w * 0.20);
    final t3 = (left: w * 0.685, top: h * 0.265, size: w * 0.20);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(GameStarAssets.top3Frame, fit: BoxFit.fill),
            ),

            _avatarOnly(user: _t1, left: t1.left, top: t1.top, size: t1.size),
            _avatarOnly(user: _t2, left: t2.left, top: t2.top, size: t2.size),
            _avatarOnly(user: _t3, left: t3.left, top: t3.top, size: t3.size),

            _textOnly(
              user: _t1,
              left: t1.left,
              top: t1.top + t1.size * 0.92,
              size: t1.size,
            ),
            _textOnly(
              user: _t2,
              left: t2.left,
              top: t2.top + t2.size * 0.92,
              size: t2.size,
            ),
            _textOnly(
              user: _t3,
              left: t3.left,
              top: t3.top + t3.size * 0.92,
              size: t3.size,
            ),

            Positioned(
              left: w * 0.06,
              right: w * 0.06,
              top: h * 0.40,
              bottom: h * 0.04,
              child: _rest.isEmpty
                  ? const Center(
                      child: Text(
                        'No more rankings yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      itemCount: _rest.length,
                      itemBuilder: (context, i) => _ListCardRow(user: _rest[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarOnly({
    required GameStarUserRank? user,
    required double left,
    required double top,
    required double size,
  }) {
    final avatar = size * 0.72;
    return Positioned(
      left: left + (size - avatar) / 2,
      top: top + size * 0.08,
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

  Widget _textOnly({
    required GameStarUserRank? user,
    required double left,
    required double top,
    required double size,
  }) {
    return Positioned(
      left: left - size * 0.1,
      top: top,
      width: size * 1.2,
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
              fontSize: (size * 0.14).clamp(9.0, 12.0),
              shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
            ),
          ),
          Text(
            user != null ? 'ID ${user.displayId}' : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: (size * 0.1).clamp(8.0, 10.0),
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.monetization_on,
                color: const Color(0xFFFFD54F),
                size: (size * 0.12).clamp(10.0, 13.0),
              ),
              const SizedBox(width: 2),
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
        ],
      ),
    );
  }
}

class _ListCardRow extends StatelessWidget {
  const _ListCardRow({required this.user});

  final GameStarUserRank user;

  static const double _rowAspect = 572 / 168;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowW = constraints.maxWidth;
        final rowH = (rowW / _rowAspect).clamp(40.0, 56.0);
        return Container(
          height: rowH,
          width: rowW,
          margin: const EdgeInsets.only(bottom: 5),
          padding: EdgeInsets.symmetric(horizontal: rowW * 0.04),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(GameStarAssets.listCard),
              fit: BoxFit.fill,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${user.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                width: rowH * 0.62,
                height: rowH * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 1.2,
                  ),
                ),
                child: ClipOval(
                  child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.black45,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'ID ${user.displayId}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.monetization_on,
                color: Color(0xFFFFD54F),
                size: 13,
              ),
              const SizedBox(width: 2),
              Text(
                formatGameStarScore(user.score),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
