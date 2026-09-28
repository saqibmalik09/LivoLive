import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';
import 'package:sk_live/features/home/presentation/widgets/agency_level_nameplate.dart';

class ProfileBadgeGallery extends ConsumerWidget {
  const ProfileBadgeGallery({
    super.key,
    required this.userId,
    required this.frames,
    required this.cars,
    this.onViewAll,
  });

  final String userId;
  final List<dynamic> frames;
  final List<dynamic> cars;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(userBadgesProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(title: 'Badge Gallery', onViewAll: onViewAll),
        badgesAsync.when(
          data: (badges) {
            final medals = badges.where((b) => b.type == 'medal').toList();
            final previewItems = <_GalleryItem>[
              ...frames.map(
                (f) => _GalleryItem(
                  imageUrl: f['image_url']?.toString(),
                  label: f['name']?.toString() ?? 'Frame',
                ),
              ),
              ...cars.map(
                (c) => _GalleryItem(
                  imageUrl: c['image_url']?.toString(),
                  label: c['name']?.toString() ?? 'Car',
                ),
              ),
              ...medals.map(
                (m) =>
                    _GalleryItem(imageUrl: m.imageUrl, label: m.name, badge: m),
              ),
            ];

            if (previewItems.isEmpty) return _emptySlot();

            return SizedBox(
              height: 88,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: previewItems.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = previewItems[index];
                  if (item.badge != null &&
                      (item.badge!.type == 'agency' ||
                          item.badge!.type == 'family')) {
                    return SizedBox(
                      width: 100,
                      child: AgencyLevelNameplate(
                        agencyName: item.badge!.name,
                        badgeUrl: item.badge!.imageUrl,
                        height: 28,
                        maxWidth: 100,
                      ),
                    );
                  }
                  return _BadgeTile(item: item);
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 88,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
          error: (_, _) => _emptySlot(),
        ),
      ],
    );
  }

  Widget _emptySlot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 88,
        decoration: ProfileScreenTheme.glassCard(radius: 16),
        child: Center(
          child: Icon(
            Iconsax.medal,
            size: 36,
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _GalleryItem {
  const _GalleryItem({this.imageUrl, required this.label, this.badge});

  final String? imageUrl;
  final String label;
  final UserBadgeModel? badge;
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.item});

  final _GalleryItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: ProfileScreenTheme.glassCard(radius: 14),
              padding: const EdgeInsets.all(8),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.contain,
                    )
                  : Icon(
                      Iconsax.medal,
                      color: AppColors.accent.withValues(alpha: 0.7),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
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
  }
}
