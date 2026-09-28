import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/widgets/game_star_timer.dart';

class GameStarHeader extends StatelessWidget {
  const GameStarHeader({
    super.key,
    required this.event,
    required this.winner,
    required this.onRulesTap,
  });

  final PartyEvent event;
  final GameStarUserRank? winner;
  final VoidCallback onRulesTap;

  @override
  Widget build(BuildContext context) {
    final title = event.title.isNotEmpty ? event.title : 'Game Star';
    final dateLabel = _dateRangeLabel(event.startAt, event.endAt);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Image.asset(
                    GameStarAssets.backButton,
                    width: 44,
                    height: 44,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFE082),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          shadows: [
                            Shadow(blurRadius: 8, color: Color(0xAAFF1744)),
                            Shadow(blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                      ),
                      if (dateLabel.isNotEmpty)
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRulesTap,
                  child: Image.asset(
                    GameStarAssets.rulesButton,
                    width: 72,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text(
                      'Rules',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _WinnerThrone(winner: winner),
        const SizedBox(height: 10),
        GameStarTimer(endAt: event.endAt),
        const SizedBox(height: 12),
      ],
    );
  }

  String _dateRangeLabel(DateTime? start, DateTime? end) {
    String fmt(DateTime d) {
      final local = d.toLocal();
      return '${local.month.toString().padLeft(2, '0')}/'
          '${local.day.toString().padLeft(2, '0')}';
    }

    if (start != null && end != null) {
      return '${fmt(start)} - ${fmt(end)}';
    }
    if (end != null) return 'Until ${fmt(end)}';
    return '';
  }
}

class _WinnerThrone extends StatelessWidget {
  const _WinnerThrone({required this.winner});

  final GameStarUserRank? winner;

  static const double _frameW = 260;
  static const double _frameH = 200;
  static const double _avatarFrac = 0.38;

  @override
  Widget build(BuildContext context) {
    final name = winner?.displayName ?? 'GAME STAR';
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
                color: const Color(0xFF2A0A0A),
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
            child: Image.asset(GameStarAssets.topFrame, fit: BoxFit.contain),
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
      color: const Color(0xFF3A1010),
      child: Center(
        child: Icon(
          Icons.sports_esports,
          color: const Color(0xFFFFD54F),
          size: size * 0.4,
        ),
      ),
    );
  }
}
