import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';

class GameStarGamesRow extends ConsumerStatefulWidget {
  const GameStarGamesRow({
    super.key,
    required this.eventId,
    required this.selectedGameId,
    required this.onGameSelected,
  });

  final String eventId;
  final String? selectedGameId;
  final ValueChanged<String> onGameSelected;

  @override
  ConsumerState<GameStarGamesRow> createState() => _GameStarGamesRowState();
}

class _GameStarGamesRowState extends ConsumerState<GameStarGamesRow> {
  final ScrollController _scroll = ScrollController();
  bool _canLeft = false;
  bool _canRight = true;
  bool _didAutoSelect = false;

  static const double _cardAspect = 533 / 440;
  static const double _focusAspect = 552 / 464;
  static const double _cardH = 72;
  static const double _focusH = 82;
  static const double _gap = 8;
  static const double _arrowSize = 34;

  double get _cardW => _cardH * _cardAspect;
  double get _focusW => _focusH * _focusAspect;
  double get _step => _cardW + _gap;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncArrows);
    _scroll.dispose();
    super.dispose();
  }

  void _syncArrows() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final offset = _scroll.offset;
    final left = offset > 2;
    final right = offset < max - 2;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _syncArrows();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gameStarGamesProvider(widget.eventId));
    final games = async.valueOrNull ?? const <GameStarGameItem>[];

    if (!_didAutoSelect &&
        games.isNotEmpty &&
        (widget.selectedGameId == null || widget.selectedGameId!.isEmpty)) {
      _didAutoSelect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onGameSelected(games.first.id);
      });
    }

    final slots = games.isEmpty
        ? List<GameStarGameItem?>.filled(4, null)
        : games.map<GameStarGameItem?>((g) => g).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: SizedBox(
        height: _focusH + 4,
        child: Row(
          children: [
            _ScrollArrow3D(
              direction: _ArrowDir.left,
              enabled: _canLeft,
              size: _arrowSize,
              onTap: () => _scrollBy(-_step),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _syncArrows();
                  return false;
                },
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: slots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, i) {
                    final game = slots[i];
                    final focused =
                        game != null && game.id == widget.selectedGameId;
                    return GestureDetector(
                      onTap: game == null
                          ? null
                          : () => widget.onGameSelected(game.id),
                      child: _GameCard(
                        game: game,
                        focused: focused,
                        width: focused ? _focusW : _cardW,
                        height: focused ? _focusH : _cardH,
                      ),
                    );
                  },
                ),
              ),
            ),
            _ScrollArrow3D(
              direction: _ArrowDir.right,
              enabled: _canRight,
              size: _arrowSize,
              onTap: () => _scrollBy(_step),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ArrowDir { left, right }

class _ScrollArrow3D extends StatelessWidget {
  const _ScrollArrow3D({
    required this.direction,
    required this.enabled,
    required this.size,
    required this.onTap,
  });

  final _ArrowDir direction;
  final bool enabled;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLeft = direction == _ArrowDir.left;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF3C4),
                Color(0xFFFFD54F),
                Color(0xFFC62828),
                Color(0xFF8B0000),
              ],
              stops: [0.0, 0.28, 0.7, 1.0],
            ),
            border: Border.all(color: const Color(0xFFFFF8E1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isLeft ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
            color: Colors.white,
            size: size * 0.38,
            shadows: const [
              Shadow(
                offset: Offset(0, 1.5),
                blurRadius: 2,
                color: Color(0x88000000),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.focused,
    required this.width,
    required this.height,
  });

  final GameStarGameItem? game;
  final bool focused;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final iconSize = width * 0.50;
    final name = game?.name.trim().isNotEmpty == true ? game!.name.trim() : '';

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              focused ? GameStarAssets.gameFocusCard : GameStarAssets.gameCard,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
          Positioned(
            left: width * 0.10,
            right: width * 0.10,
            top: height * 0.05,
            bottom: height * 0.06,
            child: Column(
              children: [
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: game != null && game!.iconUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: game!.iconUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Icon(
                              Icons.sports_esports,
                              color: Colors.white54,
                              size: iconSize * 0.7,
                            ),
                          )
                        : Icon(
                            Icons.sports_esports,
                            color: Colors.white38,
                            size: iconSize * 0.7,
                          ),
                  ),
                ),
                const Spacer(),
                Text(
                  name.isNotEmpty ? name : 'Game',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: (width * 0.11).clamp(8.0, 10.0),
                    height: 1.05,
                    shadows: const [
                      Shadow(blurRadius: 3, color: Colors.black87),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
