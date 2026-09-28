import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_screen_theme.dart';

class LevelUserProgressCard extends StatelessWidget {
  const LevelUserProgressCard({
    super.key,
    required this.theme,
    required this.username,
    required this.avatarUrl,
    required this.currentLevel,
    required this.nextLevel,
    required this.currentValue,
    required this.expToNext,
    required this.progress,
  });

  final LevelScreenTheme theme;
  final String username;
  final String? avatarUrl;
  final int currentLevel;
  final int nextLevel;
  final num currentValue;
  final num expToNext;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: theme.cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white12,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? Icon(Icons.person, color: theme.accentColor)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currentValue',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _LevelNode(label: 'LV$currentLevel', theme: theme, active: true),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.accentColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: theme.accentColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _LevelNode(label: 'LV$nextLevel', theme: theme, active: false),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'Need ${expToNext.clamp(0, double.infinity).toInt()} Exp to Lv.$nextLevel',
              style: TextStyle(
                color: theme.accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.label,
    required this.theme,
    required this.active,
  });

  final String label;
  final LevelScreenTheme theme;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? theme.accentColor.withValues(alpha: 0.2)
            : Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? theme.accentColor : Colors.white24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? theme.accentColor : Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
