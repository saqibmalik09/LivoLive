import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/weekly_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';

class WeeklyStarRankBoard extends StatelessWidget {
  const WeeklyStarRankBoard({
    super.key,
    required this.title,
    required this.rankings,
    this.loadingMore = false,
  });

  final String title;
  final List<WeeklyStarUserRank> rankings;
  final bool loadingMore;

  static const double _aspect = 249 / 600;

  WeeklyStarUserRank? get _t1 => rankings.isNotEmpty ? rankings.first : null;
  WeeklyStarUserRank? get _t2 => rankings.length > 1 ? rankings[1] : null;
  WeeklyStarUserRank? get _t3 => rankings.length > 2 ? rankings[2] : null;
  List<WeeklyStarUserRank> get _rest =>
      rankings.length > 3 ? rankings.sublist(3) : const [];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 16;
    final h = w / _aspect;

    final t1 = (left: w * 0.5 - (w * 0.12), top: h * 0.138, size: w * 0.24);
    final t2 = (left: w * 0.09, top: h * 0.248, size: w * 0.20);
    final t3 = (left: w * 0.71, top: h * 0.248, size: w * 0.20);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            _avatarOnly(user: _t1, left: t1.left, top: t1.top, size: t1.size),
            _avatarOnly(user: _t2, left: t2.left, top: t2.top, size: t2.size),
            _avatarOnly(user: _t3, left: t3.left, top: t3.top, size: t3.size),

            Positioned.fill(
              child: Image.asset(WeeklyStarAssets.top3, fit: BoxFit.fill),
            ),

            Positioned(
              left: w * 0.22,
              top: h * 0.012,
              width: w * 0.56,
              height: h * 0.045,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
            ),

            _textOnly(
              user: _t1,
              rankLabel: 'TOP 1',
              left: t1.left,
              top: t1.top + t1.size * 0.82,
              size: t1.size,
              nameplateColor: const Color(0xFFC62828),
            ),
            _textOnly(
              user: _t2,
              rankLabel: 'TOP 2',
              left: t2.left,
              top: t2.top + t2.size * 0.82,
              size: t2.size,
              nameplateColor: const Color(0xFF1565C0),
            ),
            _textOnly(
              user: _t3,
              rankLabel: 'TOP 3',
              left: t3.left,
              top: t3.top + t3.size * 0.82,
              size: t3.size,
              nameplateColor: const Color(0xFF2E7D32),
            ),

            Positioned(
              left: w * 0.07,
              right: w * 0.07,
              top: h * 0.42,
              bottom: h * 0.055,
              child: _rest.isEmpty
                  ? const Center(
                      child: Text(
                        'No rankings yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      itemCount: _rest.length + (loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _rest.length) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return _RankRow(user: _rest[i]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarOnly({
    required WeeklyStarUserRank? user,
    required double left,
    required double top,
    required double size,
  }) {
    final avatar = size * 0.78;
    return Positioned(
      left: left + (size - avatar) / 2,
      top: top,
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
    required WeeklyStarUserRank? user,
    required String rankLabel,
    required double left,
    required double top,
    required double size,
    required Color nameplateColor,
  }) {
    return Positioned(
      left: left - size * 0.08,
      top: top,
      width: size * 1.16,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                rankLabel,
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3.2
                    ..color = const Color(0xFF5D4037),
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF8E1),
                      Color(0xFFFFD54F),
                      Color(0xFFFFA000),
                      Color(0xFFFFD54F),
                    ],
                    stops: [0.0, 0.35, 0.7, 1.0],
                  ).createShader(bounds);
                },
                child: Text(
                  rankLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 2),
                        blurRadius: 4,
                        color: Color(0xAAFF6F00),
                      ),
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 8,
                        color: Color(0x88FFD54F),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            width: size,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: nameplateColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
            ),
            child: Text(
              user?.displayName ?? '--',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user != null ? 'ID ${user.displayId}' : '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 8,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Color(0xFFFFD54F), size: 11),
              const SizedBox(width: 2),
              Text(
                user != null ? formatWeeklyStarScore(user.score) : '0',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.user});

  final WeeklyStarUserRank user;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFB8860B), Color(0xFFFFE082), Color(0xFFB8860B)],
        ),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${user.rank}',
              style: const TextStyle(
                color: Color(0xFF3E2723),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: ClipOval(
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.avatarUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.brown[700],
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
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'ID ${user.displayId}',
                  style: TextStyle(
                    color: const Color(0xFF3E2723).withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.star, color: Color(0xFFE65100), size: 13),
          const SizedBox(width: 2),
          Text(
            formatWeeklyStarScore(user.score),
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
