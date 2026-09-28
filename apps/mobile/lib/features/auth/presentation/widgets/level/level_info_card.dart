import 'package:flutter/material.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_screen_theme.dart';

class LevelInfoCard extends StatelessWidget {
  const LevelInfoCard({super.key, required this.theme});

  final LevelScreenTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme.infoTitle,
            style: TextStyle(
              color: theme.accentColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            theme.infoBody,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
