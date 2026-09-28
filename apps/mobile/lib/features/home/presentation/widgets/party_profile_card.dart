import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/providers/party_people_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/profile_cover_carousel.dart';

class PartyProfileCard extends ConsumerWidget {
  const PartyProfileCard({super.key, required this.entry});

  final PartyProfileEntry entry;

  void _openProfile(BuildContext context, WidgetRef ref) {
    NavigationUtils.navigateToProfile(context, ref, entry.userId);
  }

  Future<void> _openChat(BuildContext context) async {
    await HapticFeedback.lightImpact();
    try {
      final convId = await ChatService.getOrCreateConversation(entry.userId);
      if (context.mounted) {
        context.push(
          AppRouter.chat,
          extra: {
            'conversationId': convId,
            'targetUserId': entry.userId,
            'targetUsername': entry.username,
            'targetAvatar': entry.avatarUrl,
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final covers = entry.coverImages;
    final bio = entry.bio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openProfile(context, ref),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryUltraLight,
                  backgroundImage:
                      entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(entry.avatarUrl!)
                      : null,
                  child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                      ? const Icon(Iconsax.user, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(context, ref),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        entry.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.roomTitle != null &&
                        entry.roomTitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Room: ${entry.roomTitle}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _openProfile(context, ref),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          bio,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openChat(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Hi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (covers.isNotEmpty) ...[
            const SizedBox(height: 8),
            ProfileCoverCarousel(
              imageUrls: covers,
              width: 80,
              height: 80,
              borderRadius: BorderRadius.circular(10),
              dotsOverlay: true,
              memCacheWidth: 240,
              onTap: () => _openProfile(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
