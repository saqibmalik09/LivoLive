import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/weekly_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/widgets/weekly_star_timer.dart';

class WeeklyStarHeader extends StatelessWidget {
  const WeeklyStarHeader({
    super.key,
    required this.title,
    required this.endAt,
    required this.winner,
  });

  final String title;
  final DateTime? endAt;
  final WeeklyStarUserRank? winner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 360,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0xCC000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.55, 0.82, 1.0],
                  ).createShader(bounds);
                },
                child: Image.asset(
                  WeeklyStarAssets.hero,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.25),
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF3D2A6B), Color(0xFF0A0618)],
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                      const Color(0xFF0A0618).withValues(alpha: 0.55),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              title.isNotEmpty
                                  ? title
                                  : context.l10n.event_shiningStarLastWeek,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFE082),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                shadows: [
                                  Shadow(
                                    blurRadius: 10,
                                    color: Color(0xAAFF4081),
                                  ),
                                  Shadow(blurRadius: 4, color: Colors.black54),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: const Alignment(0, 0.35),
                        child: _WinnerSpotlight(winner: winner),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        WeeklyStarTimer(endAt: endAt),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _WinnerSpotlight extends StatelessWidget {
  const _WinnerSpotlight({required this.winner});

  final WeeklyStarUserRank? winner;

  static const double _frameW = 260;
  static const double _frameH = 200;
  static const double _avatarFrac = 0.38;

  @override
  Widget build(BuildContext context) {
    final name = winner?.displayName ?? 'TEAM STAR';
    final avatarSize = _frameW * _avatarFrac;

    return SizedBox(
      width: _frameW,
      height: _frameH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: _frameH * 0.28,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A0A2E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipOval(
                child:
                    winner?.avatarUrl != null && winner!.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: winner!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _placeholder(avatarSize),
                      )
                    : _placeholder(avatarSize),
              ),
            ),
          ),
          Positioned.fill(
            child: Image.asset(WeeklyStarAssets.topFrame, fit: BoxFit.contain),
          ),
          Positioned(
            left: _frameW * 0.22,
            right: _frameW * 0.22,
            bottom: _frameH * 0.11,
            height: _frameH * 0.14,
            child: Center(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(double size) {
    return ColoredBox(
      color: const Color(0xFF2A1450),
      child: Center(
        child: Text(
          'TEAM\nSTAR',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFFFD54F),
            fontWeight: FontWeight.w900,
            fontSize: size * 0.14,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
