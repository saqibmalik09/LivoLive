import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/su_games_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/features/games/presentation/pages/h5_game_webview_page.dart';
import 'package:sk_live/features/games/presentation/widgets/game_ref_widgets.dart';
import 'package:sk_live/features/rupee_game/presentation/pages/rupee_game_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_screen.dart';

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

  void _openWallet(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(suGamesHubProvider);
    final s = GameRefLayout.scaleOf(context);
    final top = GameRefLayout.topShift(context);
    final navTop = GameRefLayout.navTop(context);
    final screenH = MediaQuery.sizeOf(context).height;

    Widget middle(Widget child) => Positioned(
      left: 0,
      right: 0,
      top: (navTop + 43 - 268) * s,
      height: 268 * s,
      child: Center(child: child),
    );

    final categories = (hubAsync.valueOrNull ?? const <SuGameCategory>[])
        .where((c) => c.games.isNotEmpty)
        .toList();
    final games = [for (final c in categories) ...c.games];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          child: SizedBox(
            height: screenH,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(child: GameRefBackground()),
                Positioned(
                  left: 0,
                  top: (34 + top) * s,
                  width: 750 * s,
                  height: 340 * s,
                  child: const GameRefBigWin(),
                ),
                Positioned(
                  left: 0,
                  top: (83 + top) * s,
                  child: GameRefTopBar(onRecharge: () => _openWallet(context)),
                ),
                ...hubAsync.when<List<Widget>>(
                  loading: () => [middle(const CircularProgressIndicator())],
                  error: (e, _) => [middle(asyncErrorWidget(e))],
                  data: (_) {
                    if (games.isEmpty) {
                      return [
                        middle(
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.game,
                                size: 64,
                                color: Colors.white70,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No games yet.\nCheck back soon!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }
                    return [
                      PositionedDirectional(
                        end: 0,
                        top: (navTop - 272) * s,
                        child: GameRefMoreButton(
                          label: context.l10n.common_more,
                          onTap: () => GameRefMorePanel.show(
                            context,
                            categories: categories,
                            onOpen: (game) => _openGame(context, game),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (navTop + 43 - 268) * s,
                        child: GameRefCarousel(
                          games: games,
                          onOpen: (game) => _openGame(context, game),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
