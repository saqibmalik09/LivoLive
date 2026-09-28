import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';

class LevelBadgeTableHeader extends StatelessWidget {
  const LevelBadgeTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Level',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Exp Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Next Level',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LevelBadgeTableSliver extends StatelessWidget {
  const LevelBadgeTableSliver({
    super.key,
    required this.levelConfigs,
    required this.kind,
    required this.fallbackIcon,
    required this.fallbackIconColor,
  });

  final List<Map<String, dynamic>> levelConfigs;
  final UserLevelKind kind;
  final IconData fallbackIcon;
  final Color fallbackIconColor;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final config = index < levelConfigs.length
              ? levelConfigs[index]
              : null;
          if (config == null) return const SizedBox();

          final level = config['level'];
          final minExp = config['min_exp'];
          var needs = 0;
          if (index + 1 < levelConfigs.length) {
            needs = levelConfigs[index + 1]['min_exp'] - minExp;
          }

          final badgeUrl = badgeUrlForLevelConfig(kind, config);

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              border: const Border(
                left: BorderSide(color: Colors.white10),
                right: BorderSide(color: Colors.white10),
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (badgeUrl != null)
                        CachedNetworkImage(
                          imageUrl: badgeUrl,
                          height: 24,
                          width: 24,
                          placeholder: (context, url) =>
                              const SizedBox(width: 24, height: 24),
                          errorWidget: (context, url, error) => Icon(
                            fallbackIcon,
                            color: fallbackIconColor,
                            size: 16,
                          ),
                        )
                      else
                        Text(
                          'Lv.$level',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '$minExp',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    needs > 0 ? '$needs' : '-',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }, childCount: levelConfigs.length),
      ),
    );
  }
}
