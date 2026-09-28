import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_games_row.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_header.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_history_tab.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_my_rank_bar.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_rank_tab.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_reward_tab.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_rules_popup.dart';

class GameStarEventScreen extends ConsumerStatefulWidget {
  const GameStarEventScreen({super.key, required this.event});

  final PartyEvent event;

  @override
  ConsumerState<GameStarEventScreen> createState() =>
      _GameStarEventScreenState();
}

class _GameStarEventScreenState extends ConsumerState<GameStarEventScreen> {
  int _tabIndex = 1;
  String? _selectedGameId;

  @override
  Widget build(BuildContext context) {
    final winnerAsync = ref.watch(
      gameStarFeaturedWinnerProvider((
        eventId: widget.event.id,
        gameId: _selectedGameId,
      )),
    );
    final myRankAsync = ref.watch(
      myGameStarRankProvider((
        eventId: widget.event.id,
        periodKey: 'current',
        gameId: _selectedGameId,
      )),
    );
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final screenH = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0505),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: screenH * 0.28,
            left: 0,
            right: 0,
            bottom: 0,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xCC000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x99000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.12, 0.28, 0.72, 0.9, 1.0],
                ).createShader(bounds);
              },
              child: Image.asset(
                GameStarAssets.background,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: GameStarHeader(
                        event: widget.event,
                        winner: winnerAsync.valueOrNull,
                        onRulesTap: () {
                          showGameStarRulesPopup(
                            context,
                            rules: gameStarRulesFromEvent(widget.event),
                            startAt: widget.event.startAt,
                            endAt: widget.event.endAt,
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: GameStarGamesRow(
                        eventId: widget.event.id,
                        selectedGameId: _selectedGameId,
                        onGameSelected: (id) {
                          setState(() => _selectedGameId = id);
                        },
                      ),
                    ),
                    SliverToBoxAdapter(child: _tabs()),
                    SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey('${_tabIndex}_$_selectedGameId'),
                          child: _buildTabBody(),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ],
                ),
              ),
              if (_tabIndex == 1)
                GameStarMyRankBar(
                  me: myRankAsync.valueOrNull,
                  fallbackName: profile?['username']?.toString(),
                  fallbackAvatar: profile?['avatar_url']?.toString(),
                  fallbackShortId: profile?['short_id']?.toString(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          _tabBtn('History', 0),
          const SizedBox(width: 8),
          _tabBtn('Ranking', 1),
          const SizedBox(width: 8),
          _tabBtn('Reward', 2),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                selected
                    ? GameStarAssets.selectedButton
                    : GameStarAssets.button,
              ),
              fit: BoxFit.fill,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_tabIndex) {
      0 => GameStarHistoryTab(
        eventId: widget.event.id,
        gameId: _selectedGameId,
      ),
      2 => GameStarRewardTab(event: widget.event),
      _ => GameStarRankTab(eventId: widget.event.id, gameId: _selectedGameId),
    };
  }
}
