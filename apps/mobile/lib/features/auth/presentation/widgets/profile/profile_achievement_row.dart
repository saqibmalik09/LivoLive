import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';

class ProfileAchievementRow extends ConsumerWidget {
  const ProfileAchievementRow({
    super.key,
    required this.userId,
    required this.vipLevel,
    this.svipLevel = 0,
    this.onVipTap,
    this.onSvipTap,
  });

  final String userId;
  final int vipLevel;
  final int svipLevel;
  final VoidCallback? onVipTap;
  final VoidCallback? onSvipTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vipCardAsync = ref.watch(vipCardProvider(vipLevel));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _AchievementCard(
              title: 'VIP',
              subtitle: 'VIP Lv$vipLevel',
              onTap: onVipTap,
              child: vipCardAsync.when(
                data: (cardUrl) {
                  if (cardUrl != null && cardUrl.trim().isNotEmpty) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppNetworkImage(
                        imageUrl: cardUrl,
                        width: 72,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                    );
                  }
                  return _fallbackShield(
                    icon: Iconsax.crown_1,
                    colors: const [AppColors.gold, AppColors.goldDark],
                  );
                },
                loading: () => _fallbackShield(
                  icon: Iconsax.crown_1,
                  colors: const [AppColors.gold, AppColors.goldDark],
                ),
                error: (_, _) => _fallbackShield(
                  icon: Iconsax.crown_1,
                  colors: const [AppColors.gold, AppColors.goldDark],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _AchievementCard(
              title: 'Charm',
              subtitle: vipLevel > 0 ? 'Active VIP' : 'Grow charm',
              onTap: onSvipTap,
              child: _fallbackShield(
                icon: Iconsax.heart,
                colors: const [AppColors.accent, AppColors.accentDark],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackShield({
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: ProfileScreenTheme.glassCard(radius: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
