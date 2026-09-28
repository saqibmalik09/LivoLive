import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_screen_theme.dart';

class LevelRewardGrid extends StatelessWidget {
  const LevelRewardGrid({
    super.key,
    required this.theme,
    required this.rewards,
    required this.currentLevel,
    required this.targetLevel,
  });

  final LevelScreenTheme theme;
  final List<Map<String, dynamic>> rewards;
  final int currentLevel;
  final int targetLevel;

  static const _labels = {
    'frame': 'Frame',
    'bubble': 'Bubble',
    'card_background': 'Card background',
    'entrance': 'Entrance',
  };

  @override
  Widget build(BuildContext context) {
    final tiles = levelRewardFeatureKeys.map((key) {
      Map<String, dynamic>? match;
      for (final reward in rewards) {
        if (reward['feature_key'] == key) {
          match = reward;
          break;
        }
      }

      final shopItem = match?['shop_items'] as Map?;
      final imageUrl = shopItem?['image_url']?.toString();
      final hasReward = imageUrl != null && imageUrl.isNotEmpty;
      final unlocked = currentLevel >= targetLevel;

      return _RewardTile(
        theme: theme,
        label: _labels[key] ?? key,
        imageUrl: hasReward ? imageUrl : null,
        level: targetLevel,
        unlocked: unlocked && hasReward,
        configured: hasReward,
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        children: [
          _SectionTitle(theme: theme, title: 'Level Reward'),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: tiles,
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.theme,
    required this.label,
    required this.imageUrl,
    required this.level,
    required this.unlocked,
    required this.configured,
  });

  final LevelScreenTheme theme;
  final String label;
  final String? imageUrl;
  final int level;
  final bool unlocked;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 56,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.contain,
                        color: unlocked ? null : Colors.white24,
                        colorBlendMode: unlocked ? null : BlendMode.modulate,
                      )
                    : Icon(
                        Iconsax.gift,
                        color: configured
                            ? theme.accentColor.withValues(alpha: 0.4)
                            : Colors.white24,
                        size: 36,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!unlocked || !configured)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock, size: 10, color: Colors.white70),
                    ),
                  Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.title});

  final LevelScreenTheme theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Iconsax.diamonds,
          size: 14,
          color: theme.accentColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.accentColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Iconsax.diamonds,
          size: 14,
          color: theme.accentColor.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
