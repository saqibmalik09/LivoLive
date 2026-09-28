import 'package:flutter/material.dart';

class VipAssets {
  static const background = 'assets/levels/vip-center-bg.webp';

  static String badgeAsset(int level) => 'assets/levels/badge-$level.webp';

  static List<String> badgeAssetCandidates(int level) => [
    'assets/levels/badge-$level.webp',
    'assets/levels/badge$level.webp',
  ];

  static String bannerAsset(int level) {
    if (level == 1) {
      return 'assets/levels/banner-1.webp';
    }
    return 'assets/levels/banner-$level.webp';
  }
}

class VipLevelTheme {
  static const levelColors = <List<Color>>[
    [Color(0xFFFFA000), Color(0xFFFF5722)],
    [Color(0xFF00BFA5), Color(0xFF0097A7)],
    [Color(0xFFFFC107), Color(0xFFFFD54F)],
    [Color(0xFF2E7D32), Color(0xFF43A047)],
    [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
    [Color(0xFF1565C0), Color(0xFF1E88E5)],
  ];

  static List<Color> colorsForIndex(int index) =>
      levelColors[index % levelColors.length];
}
