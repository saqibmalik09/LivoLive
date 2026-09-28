import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';

class LevelScreenTheme {
  const LevelScreenTheme({
    required this.backgroundColor,
    required this.accentColor,
    required this.headerGradient,
    required this.headerBackgroundAsset,
    required this.cardBorderColor,
    required this.title,
    required this.infoTitle,
    required this.infoBody,
    required this.upgradeTitle,
    required this.upgradeSubtitle,
    required this.valueLabel,
    required this.fallbackBadgeIcon,
  });

  final Color backgroundColor;
  final Color accentColor;
  final LinearGradient headerGradient;
  final String headerBackgroundAsset;
  final Color cardBorderColor;
  final String title;
  final String infoTitle;
  final String infoBody;
  final String upgradeTitle;
  final String upgradeSubtitle;
  final String valueLabel;
  final IconData fallbackBadgeIcon;

  static LevelScreenTheme forKind(UserLevelKind kind) {
    switch (kind) {
      case UserLevelKind.wealth:
        return const LevelScreenTheme(
          backgroundColor: Color(0xFF0E0A06),
          accentColor: Color(0xFFE6C27A),
          headerBackgroundAsset: 'assets/levels/wealth-level-header.webp',
          headerGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6B4F1D), Color(0xFF2A1E0D), Color(0xFF0E0A06)],
          ),
          cardBorderColor: Color(0x33E6C27A),
          title: 'Wealth',
          infoTitle: 'What is the Wealth Level?',
          infoBody:
              'Wealth level represents your social status in the app. Spending coins increases your wealth value, and reaching higher levels unlocks exclusive rewards.',
          upgradeTitle: 'Spending Coins (No Limit) +1',
          upgradeSubtitle: '1 Coins = 1 Exp',
          valueLabel: 'Wealth value',
          fallbackBadgeIcon: Icons.stars_rounded,
        );
      case UserLevelKind.charm:
        return const LevelScreenTheme(
          backgroundColor: Color(0xFF120810),
          accentColor: Color(0xFFFF6B9D),
          headerBackgroundAsset: 'assets/levels/charm-level-header.webp',
          headerGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5A2040), Color(0xFF2A1020), Color(0xFF120810)],
          ),
          cardBorderColor: Color(0x33FF6B9D),
          title: 'Charm',
          infoTitle: 'What is the Charm Level?',
          infoBody:
              'Charm level represents your popularity. Receiving diamonds increases your charm value, and higher levels unlock exclusive profile rewards.',
          upgradeTitle: 'Receiving diamonds (no limit) +1',
          upgradeSubtitle: '20 Diamonds = 1 Exp',
          valueLabel: 'Charm value',
          fallbackBadgeIcon: Icons.favorite_rounded,
        );
      case UserLevelKind.agency:
        return const LevelScreenTheme(
          backgroundColor: Color(0xFF0E0C08),
          accentColor: Color(0xFFE6A84A),
          headerBackgroundAsset: 'assets/ranking/agency/agency_bg.webp',
          headerGradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6B4A1D), Color(0xFF2A1E0D), Color(0xFF0E0C08)],
          ),
          cardBorderColor: Color(0x33E6A84A),
          title: 'Agency',
          infoTitle: 'What is the Agency Level?',
          infoBody:
              'Agency level reflects your family agency growth. Agency EXP from member earnings unlocks tier badges and profile frames for hero, honor, and charm slots.',
          upgradeTitle: 'Agency member earnings +1',
          upgradeSubtitle: 'Member gifts & activity add Agency EXP',
          valueLabel: 'Agency EXP',
          fallbackBadgeIcon: Icons.business_rounded,
        );
    }
  }
}
