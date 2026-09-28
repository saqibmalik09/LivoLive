import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_screen_theme.dart';

class LevelHowToUpgrade extends StatelessWidget {
  const LevelHowToUpgrade({super.key, required this.theme});

  final LevelScreenTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.diamonds,
                size: 14,
                color: theme.accentColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'How to level up?',
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
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accentColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  theme.title == 'Wealth'
                      ? Iconsax.coin
                      : theme.title == 'Agency'
                      ? Iconsax.building
                      : Iconsax.diamonds,
                  color: theme.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.upgradeTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      theme.upgradeSubtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
