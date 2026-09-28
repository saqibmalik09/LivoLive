import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';

class GameStarMyRankBar extends StatelessWidget {
  const GameStarMyRankBar({
    super.key,
    this.me,
    this.fallbackName,
    this.fallbackAvatar,
    this.fallbackShortId,
  });

  final GameStarUserRank? me;
  final String? fallbackName;
  final String? fallbackAvatar;
  final String? fallbackShortId;

  @override
  Widget build(BuildContext context) {
    final name = (me?.username?.trim().isNotEmpty == true)
        ? me!.username!.trim()
        : (fallbackName?.trim().isNotEmpty == true
              ? fallbackName!.trim()
              : 'User');
    final avatar = me?.avatarUrl ?? fallbackAvatar;
    final shortId = (me?.shortId?.trim().isNotEmpty == true)
        ? me!.shortId!.trim()
        : (fallbackShortId?.trim().isNotEmpty == true
              ? fallbackShortId!.trim()
              : '--');
    final score = me?.score ?? 0;
    final rankText = (me != null && me!.rank > 0) ? '${me!.rank}' : '--';

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFFD4AF37), Color(0xFF8B0000)],
          ),
          border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rankText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: ClipOval(
                child: avatar != null && avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: Colors.black26,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : Container(
                        color: Colors.black26,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'ID $shortId',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.monetization_on,
              color: Color(0xFFFFD54F),
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              formatGameStarScore(score),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
