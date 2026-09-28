import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/home_games_row_provider.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/games/presentation/pages/h5_game_webview_page.dart';

class HomeGamesIconRow extends ConsumerWidget {
  const HomeGamesIconRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeGamesRowProvider);
    return async.when(
      loading: () => const SizedBox(height: 88),
      error: (_, _) => const SizedBox.shrink(),
      data: (games) {
        if (games.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const visibleCount = 4;
              const gap = 8.0;
              final itemWidth =
                  (constraints.maxWidth - gap * (visibleCount - 1)) /
                  visibleCount;
              final iconSize = (itemWidth - 8).clamp(48.0, 58.0);

              return SizedBox(
                height: iconSize + 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: games.length,
                  separatorBuilder: (_, _) => const SizedBox(width: gap),
                  itemBuilder: (context, i) {
                    final game = games[i];
                    return _GameIconChip(
                      game: game,
                      width: itemWidth,
                      iconSize: iconSize,
                      onTap: () => _launchGame(context, game),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _launchGame(BuildContext context, HomeGameIconItem game) {
    launchH5Game(
      context,
      name: game.name,
      gameUrl: game.gameUrl,
      maintenanceMode: game.maintenanceMode,
      maintenanceMessage: game.maintenanceMessage,
      gameConfig: game.configData == null
          ? null
          : {'config_data': game.configData},
      heightPercent: game.heightPercent,
    );
  }
}

class _GameIconChip extends StatelessWidget {
  const _GameIconChip({
    required this.game,
    required this.width,
    required this.iconSize,
    required this.onTap,
  });

  final HomeGameIconItem game;
  final double width;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = iconSize * 0.28;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF3C4),
                    Color(0xFFFFB300),
                    Color(0xFFE65100),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8F00).withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius - 2),
                  color: const Color(0xFF1A1420),
                ),
                clipBehavior: Clip.antiAlias,
                child: game.iconUrl.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: game.iconUrl,
                        fit: BoxFit.cover,
                        transformWidth: 160,
                        transformHeight: 160,
                        memCacheWidth: 160,
                        placeholder: (_, _) => const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => const Icon(
                          Icons.sports_esports,
                          color: Colors.white54,
                          size: 22,
                        ),
                      )
                    : const Icon(
                        Icons.sports_esports,
                        color: Colors.white54,
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.1,
                shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
