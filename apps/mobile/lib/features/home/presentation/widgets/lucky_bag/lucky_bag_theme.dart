import 'package:flutter/material.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class LuckyBagTheme {
  LuckyBagTheme._();

  static const LinearGradient sheetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.primaryDark,
      AppColors.regalOrange,
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.background,
    ],
    stops: [0.0, 0.2, 0.42, 0.68, 1.0],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryDark, AppColors.regalOrange, AppColors.primary],
  );

  static const LinearGradient sendGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.primary, AppColors.primaryDark],
  );

  static const LinearGradient tabSelectedGradient = LinearGradient(
    colors: [AppColors.gold, AppColors.primary, AppColors.regalOrange],
  );

  static List<BoxShadow> get sendShadow => [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.35),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get tabShadow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
