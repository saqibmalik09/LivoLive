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
import 'package:sk_live/features/home/presentation/widgets/party_ref_widgets.dart';

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
    final s = PartyRefLayout.scaleOf(context);
    final avatar = entry.avatarUrl ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: 33 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90 * s,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 28 * s),
                GestureDetector(
                  onTap: () => _openProfile(context, ref),
                  child: ClipOval(
                    child: SizedBox.square(
                      dimension: 90 * s,
                      child: avatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatar,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              placeholder: (_, _) => const ColoredBox(
                                color: AppColors.primaryUltraLight,
                              ),
                              errorWidget: (_, _, _) => const ColoredBox(
                                color: AppColors.primaryUltraLight,
                                child: Icon(
                                  Iconsax.user,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : const ColoredBox(
                              color: AppColors.primaryUltraLight,
                              child: Icon(
                                Iconsax.user,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 12 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12.5 * s),
                      GestureDetector(
                        onTap: () => _openProfile(context, ref),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          entry.username,
                          style: TextStyle(
                            fontSize: 30 * s,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF0B1210),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.roomTitle != null &&
                          entry.roomTitle!.isNotEmpty) ...[
                        SizedBox(height: 5.5 * s),
                        Text(
                          'Room: ${entry.roomTitle}',
                          style: TextStyle(
                            fontSize: 24 * s,
                            color: const Color(0xFF8E9A97),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 12 * s),
                Padding(
                  padding: EdgeInsets.only(top: 2.5 * s),
                  child: GestureDetector(
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
                ),
                SizedBox(width: 34 * s),
              ],
            ),
          ),
          if (covers.isNotEmpty) ...[
            SizedBox(height: 18 * s),
            Padding(
              padding: EdgeInsetsDirectional.only(start: 34 * s),
              child: ProfileCoverCarousel(
                imageUrls: covers,
                width: 333 * s,
                height: 375 * s,
                borderRadius: BorderRadius.circular(16 * s),
                dotsOverlay: true,
                memCacheWidth: 720,
                onTap: () => _openProfile(context, ref),
              ),
            ),
          ],
          if (bio.isNotEmpty) ...[
            SizedBox(height: 14 * s),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 34 * s),
              child: GestureDetector(
                onTap: () => _openProfile(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  bio,
                  style: TextStyle(
                    fontSize: 30 * s,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF061C17),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
