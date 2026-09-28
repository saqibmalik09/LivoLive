import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/fast_circle_avatar.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';

class ProfileRelationshipCard extends ConsumerWidget {
  const ProfileRelationshipCard({
    super.key,
    required this.userId,
    required this.user,
    this.onViewAll,
  });

  final String userId;
  final Map<String, dynamic> user;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cpData = user['cp_data'] as Map<String, dynamic>?;
    final partner = cpData?['partner'] as Map<String, dynamic>?;
    final cpLevel = (cpData?['cp_level'] as num?)?.toInt() ?? 0;
    final hasPartner = partner != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(title: 'Relationship', onViewAll: onViewAll),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: ProfileScreenTheme.glassCard(radius: 20),
              child: hasPartner
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _PartnerAvatar(
                          userId: userId,
                          name: user['username']?.toString() ?? 'You',
                          avatarUrl: user['avatar_url']?.toString(),
                        ),
                        const Icon(
                          Icons.favorite,
                          color: Color(0xFFFF6B9A),
                          size: 28,
                        ),
                        _PartnerAvatar(
                          userId: partner['id']?.toString() ?? '',
                          name: partner['username']?.toString() ?? 'Partner',
                          avatarUrl: partner['avatar_url']?.toString(),
                          onTap: () => NavigationUtils.navigateToProfile(
                            context,
                            ref,
                            partner['id'].toString(),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.08),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            Icons.add,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Build',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (cpLevel > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: ProfileScreenTheme.ctaGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'CP Lv.$cpLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PartnerAvatar extends ConsumerWidget {
  const _PartnerAvatar({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.onTap,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameAsync = ref.watch(userEquippedFrameProvider(userId));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          frameAsync.when(
            data: (frame) => Stack(
              alignment: Alignment.center,
              children: [
                FastCircleAvatar(
                  radius: 32,
                  imageUrl: avatarUrl,
                  backgroundColor: AppColors.surfaceElevated,
                ),
                if (frame != null)
                  SizedBox(
                    width: 88,
                    height: 88,
                    child:
                        frame['svga_url'] != null &&
                            frame['svga_url']!.toString().isNotEmpty
                        ? RaveSVGAPlayer(resUrl: frame['svga_url']!.toString())
                        : AppNetworkImage(
                            imageUrl: frame['image_url']!.toString(),
                            fit: BoxFit.contain,
                          ),
                  ),
              ],
            ),
            loading: () => FastCircleAvatar(
              radius: 32,
              imageUrl: avatarUrl,
              backgroundColor: AppColors.surfaceElevated,
            ),
            error: (_, _) => FastCircleAvatar(
              radius: 32,
              imageUrl: avatarUrl,
              backgroundColor: AppColors.surfaceElevated,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 80,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
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
