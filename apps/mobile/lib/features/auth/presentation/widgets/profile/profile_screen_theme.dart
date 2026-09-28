import 'package:flutter/material.dart';
import 'package:sk_live/core/theme/app_colors.dart';

abstract final class ProfileScreenTheme {
  static const bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.primaryUltraLight,
      AppColors.background,
      Color(0xFFFFFFFF),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const heroFade = AppColors.background;

  static const ctaGradient = AppColors.primaryGradient;

  static BoxDecoration glassCard({double radius = 18}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.surface, AppColors.surfaceElevated],
    ),
    border: Border.all(color: AppColors.border, width: 1.2),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.12),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get iconCircle => BoxDecoration(
    shape: BoxShape.circle,
    color: AppColors.primary.withValues(alpha: 0.08),
    border: Border.all(color: AppColors.border),
  );

  static BoxDecoration pillButton({bool filled = false}) => BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    color: filled ? null : AppColors.primary.withValues(alpha: 0.08),
    gradient: filled ? ctaGradient : null,
    border: filled ? null : Border.all(color: AppColors.border),
  );
}

class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.showViewAllLabel = true,
  });

  final String title;
  final VoidCallback? onViewAll;
  final bool showViewAllLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showViewAllLabel)
                    const Text(
                      'View all',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  ProfileTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.98),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant ProfileTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}
