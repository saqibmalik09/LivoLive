import 'package:flutter/material.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';

class ProfileAboutTab extends StatelessWidget {
  const ProfileAboutTab({
    super.key,
    required this.supporters,
    required this.achievement,
    required this.badgeGallery,
    this.giftWall,
    this.intimacy,
    this.posts,
  });

  final Widget supporters;
  final Widget achievement;
  final Widget badgeGallery;
  final Widget? giftWall;
  final Widget? intimacy;
  final Widget? posts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        const SizedBox(height: 8),
        supporters,
        const SizedBox(height: 16),
        achievement,
        const SizedBox(height: 16),
        badgeGallery,
        if (giftWall != null) ...[const SizedBox(height: 16), giftWall!],
        if (intimacy != null) ...[const SizedBox(height: 16), intimacy!],
        if (posts != null) ...[const SizedBox(height: 16), posts!],
      ],
    );
  }
}

class ProfileRelationshipTab extends StatelessWidget {
  const ProfileRelationshipTab({super.key, required this.relationship});

  final Widget relationship;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      children: [relationship],
    );
  }
}

class ProfileGiftInventoryStrip extends StatelessWidget {
  const ProfileGiftInventoryStrip({
    super.key,
    required this.gifts,
    this.onViewAll,
  });

  final List<dynamic> gifts;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(title: 'Gifts', onViewAll: onViewAll),
        if (gifts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 72,
              decoration: ProfileScreenTheme.glassCard(radius: 16),
              alignment: Alignment.center,
              child: const Text(
                'No gifts yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          )
        else
          SizedBox(
            height: 88,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: gifts.length.clamp(0, 20),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final g = gifts[index] as Map? ?? {};
                final url = g['image_url']?.toString();
                final name = g['name']?.toString() ?? 'Gift';
                final count = g['count'];
                return SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: ProfileScreenTheme.glassCard(radius: 14),
                          padding: const EdgeInsets.all(8),
                          child: url != null && url.isNotEmpty
                              ? Image.network(url, fit: BoxFit.contain)
                              : const Icon(
                                  Icons.card_giftcard,
                                  color: AppColors.primary,
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count != null && count is num && count > 1
                            ? '$name x$count'
                            : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
