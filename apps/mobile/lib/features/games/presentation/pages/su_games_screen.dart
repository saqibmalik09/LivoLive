import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/su_games_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/games/presentation/pages/h5_game_webview_page.dart';
import 'package:sk_live/features/home/presentation/widgets/party_screen_background.dart';
import 'package:sk_live/features/rupee_game/presentation/pages/rupee_game_screen.dart';

class SuGamesScreen extends ConsumerWidget {
  const SuGamesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(suGamesHubProvider);
    await ref.read(suGamesHubProvider.future);
  }

  void _openGame(BuildContext context, SuGameItem game) {
    if (game.isRupee) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const RupeeGameScreen()));
      return;
    }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(suGamesHubProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomPad = homeTabScrollBottomPadding(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          context.l10n.nav_game,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PartyScreenBackground(),
          hubAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => asyncErrorWidget(e),
            data: (allCategories) {
              final categories = allCategories
                  .where((c) => c.games.isNotEmpty)
                  .toList();
              if (categories.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      topInset + kToolbarHeight + 24,
                      20,
                      bottomPad,
                    ),
                    children: const [
                      SizedBox(height: 80),
                      Icon(Iconsax.game, size: 64, color: Colors.black45),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No games yet.\nCheck back soon!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topInset + kToolbarHeight + 8,
                    16,
                    bottomPad,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == categories.length - 1 ? 0 : 22,
                      ),
                      child: _SuCategorySection(
                        title: cat.name,
                        games: cat.games,
                        onOpen: (game) => _openGame(context, game),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuCategorySection extends StatelessWidget {
  const _SuCategorySection({
    required this.title,
    required this.games,
    required this.onOpen,
  });

  final String title;
  final List<SuGameItem> games;
  final ValueChanged<SuGameItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 14),
        if (games.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'No games in this category.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: games.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final game = games[index];
              return _SuGameTile(game: game, onTap: () => onOpen(game));
            },
          ),
      ],
    );
  }
}

class _SuGameTile extends StatelessWidget {
  const _SuGameTile({required this.game, required this.onTap});

  final SuGameItem game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const nameH = 15.0;
          const gap = 6.0;
          final iconSide = (constraints.maxHeight - nameH - gap).clamp(
            40.0,
            constraints.maxWidth,
          );
          return Column(
            children: [
              SizedBox(
                width: iconSide,
                height: iconSide,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                        color: const Color(0xFFFF8F00).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFF1A1420),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: game.iconUrl.isNotEmpty
                        ? AppNetworkImage(
                            imageUrl: game.iconUrl,
                            fit: BoxFit.cover,
                            transformWidth: 220,
                            transformHeight: 220,
                            memCacheWidth: 220,
                            placeholder: (_, _) => const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => Icon(
                              game.isRupee
                                  ? Iconsax.coin
                                  : Icons.sports_esports,
                              color: Colors.white54,
                              size: 24,
                            ),
                          )
                        : Icon(
                            game.isRupee ? Iconsax.coin : Icons.sports_esports,
                            color: Colors.white70,
                            size: 26,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: nameH,
                width: double.infinity,
                child: Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
