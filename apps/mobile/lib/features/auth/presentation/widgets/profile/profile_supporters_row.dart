import 'package:flutter/material.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/fast_circle_avatar.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileSupportersRow extends ConsumerWidget {
  const ProfileSupportersRow({
    super.key,
    required this.supporters,
    this.onViewAll,
  });

  final List<dynamic> supporters;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supporters.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: 'Supporters',
          onViewAll: onViewAll,
          showViewAllLabel: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            decoration: ProfileScreenTheme.glassCard(radius: 16),
            child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: supporters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final raw = supporters[index];
                  final map = raw is Map
                      ? Map<String, dynamic>.from(raw)
                      : <String, dynamic>{};
                  final id = map['id']?.toString() ?? '';
                  final name = map['username']?.toString() ?? 'User';
                  final avatar = map['avatar_url']?.toString();
                  return _SupporterTile(
                    rank: index + 1,
                    name: name,
                    avatarUrl: avatar,
                    onTap: id.isEmpty
                        ? null
                        : () => NavigationUtils.navigateToProfile(
                            context,
                            ref,
                            id,
                          ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupporterTile extends StatelessWidget {
  const _SupporterTile({
    required this.rank,
    required this.name,
    this.avatarUrl,
    this.onTap,
  });

  final int rank;
  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;

  Color? get _crownColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD54F);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFFFAB91);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crown = _crownColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            SizedBox(
              width: 52,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (crown ?? AppColors.primaryLight).withValues(
                          alpha: crown != null ? 0.85 : 0.35,
                        ),
                        width: crown != null ? 2 : 1,
                      ),
                    ),
                    child: FastCircleAvatar(
                      radius: 23,
                      imageUrl: avatarUrl,
                      backgroundColor: AppColors.surfaceElevated,
                    ),
                  ),
                  if (crown != null)
                    Positioned(
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: crown,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: crown.withValues(alpha: 0.45),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
