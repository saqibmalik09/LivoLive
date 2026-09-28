import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';

class UserMemberBadgesRow extends ConsumerWidget {
  const UserMemberBadgesRow({
    super.key,
    required this.userId,
    this.maxBadges = 20,
  });

  final String userId;
  final int maxBadges;

  static const double rowHeight = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final badgesAsync = ref.watch(userBadgesProvider(userId));
    return badgesAsync.when(
      data: (badges) {
        if (badges.isEmpty) return const SizedBox.shrink();

        final agencyBadges = badges.where((b) => b.type == 'agency').toList();
        final levelBadges = badges
            .where(
              (b) =>
                  b.type != 'medal' &&
                  b.type != 'title' &&
                  b.type != 'agency' &&
                  b.imageUrl.trim().isNotEmpty,
            )
            .toList();
        final titleBadges = badges.where((b) => b.type == 'title').toList();
        final medalBadges = badges.where((b) => b.type == 'medal').toList();

        final ordered = [
          ...agencyBadges,
          ...levelBadges,
          ...titleBadges,
          ...medalBadges,
        ].take(maxBadges).toList();

        if (ordered.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: ordered.map((b) {
            final h = b.type == 'agency'
                ? 18.0
                : (b.type == 'title'
                      ? 14.0
                      : (b.type == 'medal' ? 18.0 : 16.0));
            return UserBadgeChip(badge: b, height: h);
          }).toList(),
        );
      },
      loading: () => const SizedBox(height: rowHeight),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class UserFramedAvatar extends ConsumerWidget {
  const UserFramedAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.radius = 22,
  });

  final String userId;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frameSize = radius * 2 + 8;

    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white12,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(Icons.person, color: Colors.white38, size: radius)
                : null,
          ),
          if (userId.isNotEmpty)
            Consumer(
              builder: (context, ref, _) {
                final frameAsync = ref.watch(userEquippedFrameProvider(userId));
                return frameAsync.when(
                  data: (frame) {
                    if (frame == null) return const SizedBox.shrink();
                    final imageUrl = frame['image_url']?.toString();
                    final svgaUrl = frame['svga_url']?.toString();
                    if ((imageUrl == null || imageUrl.isEmpty) &&
                        (svgaUrl == null || svgaUrl.isEmpty)) {
                      return const SizedBox.shrink();
                    }
                    final hasSvga = svgaUrl != null && svgaUrl.isNotEmpty;
                    return IgnorePointer(
                      child: SizedBox(
                        width: frameSize,
                        height: frameSize,
                        child: hasSvga
                            ? RaveSVGAPlayer(resUrl: svgaUrl, repeat: true)
                            : CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.contain,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
        ],
      ),
    );
  }
}
