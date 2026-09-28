import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:country_picker/country_picker.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/fast_circle_avatar.dart';
import 'package:sk_live/core/widgets/special_id_badge.dart';
import 'package:sk_live/core/util/display_user_id.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_badges_row.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';

class ProfileHeroHeader extends ConsumerWidget {
  const ProfileHeroHeader({
    super.key,
    required this.userId,
    required this.user,
    required this.onStatTap,
  });

  final String userId;
  final Map<String, dynamic> user;
  final void Function(int tabIndex) onStatTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = user['stats'] as Map<String, dynamic>? ?? {};
    final totalSent = user['total_sent'] as num? ?? 0;
    final followers = stats['followers'] as num? ?? 0;
    final visitors = stats['visitors'] as num? ?? 0;

    final received = (user['total_received'] as num?)?.toInt() ?? 0;
    final bio = user['bio']?.toString().trim() ?? '';
    final username = user['username']?.toString() ?? 'User';
    final countryCode = user['country_code']?.toString().toUpperCase();
    final shortId = displayUserId(user);
    final specialIdLevel = (user['special_id_level'] as num?)?.toInt();
    final isBanned = user['is_banned'] == true;

    const avatarRadius = 48.0;
    const framePad = 32.0;
    final avatarBlock = avatarRadius * 2 + framePad;
    const bannerHeight = 200.0;
    const avatarOverlap = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: user['banner_url'] != null
                          ? AppNetworkImageProvider(user['banner_url'])
                          : AppNetworkImageProvider(user['avatar_url']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x88000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 1.0],
                      colors: [Colors.transparent, ProfileScreenTheme.heroFade],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 12,
                bottom: -avatarOverlap,
                child: SizedBox(
                  width: avatarBlock,
                  height: avatarBlock,
                  child: _AvatarWithFrame(
                    userId: userId,
                    user: user,
                    radius: avatarRadius,
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(16, avatarOverlap + 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isBanned) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Banned',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    user['gender'] == 'male' ? Iconsax.man : Iconsax.woman,
                    size: 18,
                    color: user['gender'] == 'male'
                        ? Colors.lightBlueAccent
                        : AppColors.accent,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SpecialIdBadge(
                    id: shortId,
                    level: specialIdLevel,
                    height: 20,
                  ),
                  if (countryCode != null && countryCode.isNotEmpty)
                    _CountryChip(code: countryCode),
                ],
              ),
              const SizedBox(height: 8),

              ProfileBadgesRow(userId: userId, padHorizontal: false),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Iconsax.edit_2,
                size: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bio.isEmpty
                      ? 'This user is mysterious and left nothing.'
                      : bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: ProfileScreenTheme.glassCard(radius: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCell(
                  label: 'Visitor',
                  value: _formatNumber(visitors.toInt()),
                ),
                _divider(),
                _StatCell(
                  label: 'Fans',
                  value: _formatNumber(followers.toInt()),
                  onTap: () => onStatTap(1),
                ),
                _divider(),
                _StatCell(
                  label: 'Sent',
                  value: _formatNumber(totalSent.toInt()),
                ),
                _divider(),
                _StatCell(
                  label: 'Received',
                  value: _formatNumber(received),
                  onTap: () => onStatTap(2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 24, width: 1, color: AppColors.divider);

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _AvatarWithFrame extends ConsumerWidget {
  const _AvatarWithFrame({
    required this.userId,
    required this.user,
    this.radius = 44.0,
  });

  final String userId;
  final Map<String, dynamic> user;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameAsync = ref.watch(userEquippedFrameProvider(userId));
    final frameSize = radius * 2 + 32;

    return frameAsync.when(
      data: (frameData) => SizedBox(
        width: frameSize,
        height: frameSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FastCircleAvatar(
                radius: radius,
                imageUrl: user['avatar_url']?.toString(),
                backgroundColor: AppColors.surfaceElevated,
              ),
            ),
            if (frameData != null)
              Positioned.fill(
                child: IgnorePointer(
                  child:
                      frameData['svga_url'] != null &&
                          frameData['svga_url']!.isNotEmpty
                      ? RaveSVGAPlayer(resUrl: frameData['svga_url']!)
                      : AppNetworkImage(
                          imageUrl: frameData['image_url']!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
          ],
        ),
      ),
      loading: () => FastCircleAvatar(
        radius: radius,
        imageUrl: user['avatar_url']?.toString(),
        backgroundColor: AppColors.surfaceElevated,
      ),
      error: (_, _) => FastCircleAvatar(
        radius: radius,
        imageUrl: user['avatar_url']?.toString(),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.code});

  final String code;

  String get _flag {
    try {
      return Country.parse(code).flagEmoji;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final flag = _flag;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (flag.isNotEmpty) ...[
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
        ],
        Text(
          code,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
