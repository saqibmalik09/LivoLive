import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/room_win_card_util.dart';

class RoomWinBonusCard extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final int rewardCoins;
  final int multiplier;
  final String multiplierTier;
  final String badgeLabel;
  final String variant;

  const RoomWinBonusCard({
    super.key,
    required this.username,
    required this.avatarUrl,
    required this.rewardCoins,
    required this.multiplier,
    required this.multiplierTier,
    required this.badgeLabel,
    required this.variant,
  });

  factory RoomWinBonusCard.fromRoomMessage(Map<String, dynamic> msg) {
    final metadata = _asMap(msg['metadata']);
    final type = msg['type']?.toString() ?? '';

    String variant = 'lucky';
    String badgeLabel = 'Lucky';
    int rewardCoins = 0;
    int multiplier = 1;
    String multiplierTier = 'x1';

    if (type == 'lucky_win') {
      final isLuckyPro = metadata['lucky_pro_bonus_won'] == true;
      if (isLuckyPro) {
        variant = 'lucky_pro';
        rewardCoins = _asInt(metadata['lucky_pro_bonus_coins']);
        badgeLabel = 'Pro';
      } else if (metadata['lucky_bonus_won'] == true) {
        variant = 'lucky';
        rewardCoins = _asInt(metadata['lucky_bonus_coins']);
        badgeLabel = 'Lucky';
      } else {
        variant = 'game';
        rewardCoins = _asInt(metadata['reward_coins']);
        badgeLabel =
            metadata['game_name']?.toString() ??
            metadata['source_label']?.toString() ??
            'Game';
      }
      multiplier = _asInt(metadata['bonus_multiplier'], fallback: 1);
      if (multiplier <= 0 && rewardCoins > 0) {
        final giftValue =
            _asInt(metadata['price_coins']) *
            _asInt(metadata['quantity'], fallback: 1);
        multiplier = RoomWinCardUtil.computeBonusMultiplier(
          rewardCoins: rewardCoins,
          giftValue: giftValue,
        );
      }
      multiplierTier =
          metadata['multiplier_tier']?.toString() ??
          RoomWinCardUtil.resolveMultiplierTier(multiplier);
    } else if (type == 'gift') {
      final isLuckyPro =
          metadata['is_lucky_pro_gift'] == true ||
          metadata['lucky_pro_bonus_won'] == true;

      if (isLuckyPro && metadata['lucky_pro_bonus_won'] == true) {
        variant = 'lucky_pro';
        rewardCoins = _asInt(metadata['lucky_pro_bonus_coins']);
        badgeLabel = 'Pro';
      } else if (metadata['lucky_bonus_won'] == true) {
        variant = 'lucky';
        rewardCoins = _asInt(metadata['lucky_bonus_coins']);
        badgeLabel = 'Lucky';
      }

      multiplier = _asInt(metadata['bonus_multiplier']);
      if (multiplier <= 0) {
        final giftValue =
            _asInt(metadata['price_coins']) *
            _asInt(metadata['quantity'], fallback: 1);
        multiplier = RoomWinCardUtil.computeBonusMultiplier(
          rewardCoins: rewardCoins,
          giftValue: giftValue,
        );
      }
      multiplierTier =
          metadata['multiplier_tier']?.toString() ??
          RoomWinCardUtil.resolveMultiplierTier(multiplier);
    }

    final user = _asMap(msg['user']);
    final username =
        metadata['sender_username']?.toString() ??
        user['username']?.toString() ??
        'User';
    final avatarUrl =
        metadata['sender_avatar']?.toString() ?? user['avatar_url']?.toString();

    return RoomWinBonusCard(
      username: username,
      avatarUrl: avatarUrl,
      rewardCoins: rewardCoins,
      multiplier: multiplier,
      multiplierTier: multiplierTier,
      badgeLabel: badgeLabel,
      variant: variant,
    );
  }

  factory RoomWinBonusCard.fromGlobalWin(Map<String, dynamic> row) {
    final variant = row['variant']?.toString() ?? 'lucky';
    final multiplier = _asInt(row['bonus_multiplier'], fallback: 1);
    final multiplierTier =
        row['multiplier_tier']?.toString() ??
        RoomWinCardUtil.resolveMultiplierTier(multiplier);

    String badgeLabel;
    switch (variant) {
      case 'lucky_pro':
        badgeLabel = 'Pro';
        break;
      case 'game':
        badgeLabel = row['source_label']?.toString() ?? 'Game';
        break;
      default:
        badgeLabel = 'Lucky';
    }

    return RoomWinBonusCard(
      username: row['username']?.toString() ?? 'User',
      avatarUrl: row['avatar_url']?.toString(),
      rewardCoins: _asInt(row['reward_coins']),
      multiplier: multiplier,
      multiplierTier: multiplierTier,
      badgeLabel: badgeLabel,
      variant: variant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundAsset = RoomWinCardUtil.pickBonusCardAsset(
      variant: variant,
      tier: multiplierTier,
      multiplier: multiplier,
    );
    final tierLabel = multiplierTier.startsWith('x')
        ? multiplierTier
        : 'x$multiplier';

    return SizedBox(
      width: 252,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            left: 0,
            right: 18,
            top: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(backgroundAsset, fit: BoxFit.cover),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 5, 42, 5),
                      child: Row(
                        children: [
                          _AvatarRing(avatarUrl: avatarUrl, size: 34),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.05,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    const Text(
                                      'Receive ',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        height: 1.05,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.monetization_on,
                                      color: Color(0xFFFFD54F),
                                      size: 11,
                                    ),
                                    const SizedBox(width: 1),
                                    Flexible(
                                      child: Text(
                                        '${NumberFormatter.format(rewardCoins)} rewar...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFE8F5A0),
                                          fontSize: 9,
                                          height: 1.05,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 4,
                      child: _VariantBadge(label: badgeLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
            right: -10,
            child: _GoldenMultiplierBadge(tierLabel: tierLabel),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }
}

class _GoldenMultiplierBadge extends StatelessWidget {
  final String tierLabel;

  const _GoldenMultiplierBadge({required this.tierLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBE6),
              Color(0xFFFFE566),
              Color(0xFFFFB800),
              Color(0xFFB8860B),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ).createShader(bounds),
          child: Text(
            tierLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 0.95,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Color(0xFF4A3200),
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
                Shadow(
                  color: Color(0xFF7A5500),
                  offset: Offset(0, 3),
                  blurRadius: 1,
                ),
                Shadow(
                  color: Color(0x66FFF8DC),
                  offset: Offset(0, -1),
                  blurRadius: 0,
                ),
                Shadow(
                  color: Colors.black54,
                  offset: Offset(1, 4),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
        const Text(
          'Times',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
            shadows: [
              Shadow(
                color: Color(0xFF4A3200),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VariantBadge extends StatelessWidget {
  final String label;

  const _VariantBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Color(0xFFFFD54F), size: 9),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String? avatarUrl;
  final double size;

  const _AvatarRing({required this.avatarUrl, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const ColoredBox(
                  color: Colors.white10,
                  child: Icon(Icons.person, color: Colors.white54, size: 16),
                ),
                errorWidget: (context, url, error) => const ColoredBox(
                  color: Colors.white10,
                  child: Icon(Icons.person, color: Colors.white54, size: 16),
                ),
              )
            : const ColoredBox(
                color: Colors.white10,
                child: Icon(Icons.person, color: Colors.white54, size: 16),
              ),
      ),
    );
  }
}
