import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';

class UserMomentCard extends ConsumerWidget {
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> posts;

  const UserMomentCard({super.key, required this.user, required this.posts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (posts.isEmpty) return const SizedBox.shrink();

    final userId =
        (posts.first['user_id'] ?? posts.first['author_id'])?.toString() ??
        'unknown';
    final username = user?['username'] ?? 'User';
    final avatarUrl = user?['avatar_url'];

    final List<Map<String, dynamic>> mediaItems = [];
    int totalLikes = 0;
    int totalComments = 0;

    for (var post in posts) {
      totalLikes += (post['likes_count'] as int? ?? 0);
      totalComments += (post['comments_count'] as int? ?? 0);
      final images = (post['image_urls'] as List?)?.cast<String>() ?? [];
      for (var img in images) {
        mediaItems.add({'url': img, 'post': post});
      }
      if (images.isEmpty && post['content_text'] != null) {
        mediaItems.add({'text': post['content_text'], 'post': post});
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.primaryUltraLight.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => NavigationUtils.navigateToProfile(
                        context,
                        ref,
                        userId,
                      ),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final frameAsync = ref.watch(
                            userEquippedFrameProvider(userId),
                          );
                          return SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: avatarUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: avatarUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: AppColors.primary,
                                          ),
                                  ),
                                ),
                                frameAsync.when(
                                  data: (frame) {
                                    if (frame == null)
                                      return const SizedBox.shrink();
                                    final frameUrl =
                                        frame['image_url'] ?? frame['svga_url'];
                                    if (frameUrl == null)
                                      return const SizedBox.shrink();

                                    return Positioned.fill(
                                      child: IgnorePointer(
                                        child:
                                            (frame['svga_url'] != null &&
                                                frame['svga_url']!.isNotEmpty)
                                            ? RaveSVGAPlayer(
                                                resUrl: frame['svga_url']!,
                                                fit: BoxFit.fill,
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: frame['image_url']!,
                                                fit: BoxFit.fill,
                                              ),
                                      ),
                                    );
                                  },
                                  loading: () => const SizedBox.shrink(),
                                  error: (e, s) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => NavigationUtils.navigateToProfile(
                          context,
                          ref,
                          userId,
                        ),
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await HapticFeedback.lightImpact();
                        final isFollowed = posts.first['is_followed'] == true;
                        await SocialService.toggleFollow(
                          ref,
                          userId,
                          isFollowed,
                        );
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: (posts.first['is_followed'] == true)
                            ? Colors.transparent
                            : AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: (posts.first['is_followed'] == true)
                              ? BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                )
                              : BorderSide.none,
                        ),
                      ),
                      child: Text(
                        (posts.first['is_followed'] == true)
                            ? 'Following'
                            : '+ Follow',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: (posts.first['is_followed'] == true)
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _showSafetyMenu(context, userId, username),
                      icon: const Icon(
                        Icons.more_horiz,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final badgesAsync = ref.watch(userBadgesProvider(userId));
                      return badgesAsync.when(
                        data: (badges) {
                          return Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...badges.map(
                                (badge) => _buildBadgeWidget(badge),
                              ),
                              Text(
                                '• ${posts.isNotEmpty ? timeago.format(DateTime.parse(posts.first['created_at'].toString())) : 'Just now'}',
                                style: const TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );
                        },
                        loading: () => Text(
                          '• ${posts.isNotEmpty ? timeago.format(DateTime.parse(posts.first['created_at'].toString())) : 'Just now'}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                        error: (e, s) => Text(
                          '• ${posts.isNotEmpty ? timeago.format(DateTime.parse(posts.first['created_at'].toString())) : 'Just now'}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          if (mediaItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: mediaItems.length.clamp(0, 6),
                itemBuilder: (context, index) {
                  final item = mediaItems[index];
                  return GestureDetector(
                    onTap: () =>
                        context.push(AppRouter.postDetail, extra: item['post']),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: item['url'] != null
                            ? CachedNetworkImage(
                                imageUrl: item['url'],
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Shimmer.fromColors(
                                      baseColor: AppColors.shimmerBase,
                                      highlightColor:
                                          AppColors.shimmerHighlight,
                                      child: Container(color: Colors.white),
                                    ),
                                errorWidget: (context, url, err) => Container(
                                  color: AppColors.primaryUltraLight,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryUltraLight,
                                      Colors.white,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    item['text'],
                                    maxLines: 4,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                _buildInteractionItem(
                  icon: Icons.favorite_border,
                  label: '$totalLikes',
                  onTap: () => _navigateToMoments(
                    context,
                    ref,
                    userId,
                    username,
                    avatarUrl,
                  ),
                ),
                const SizedBox(width: 20),
                _buildInteractionItem(
                  icon: Iconsax.message_text,
                  label: '$totalComments',
                  onTap: () => _navigateToMoments(
                    context,
                    ref,
                    userId,
                    username,
                    avatarUrl,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await HapticFeedback.lightImpact();
                    try {
                      final convId = await ChatService.getOrCreateConversation(
                        userId,
                      );
                      if (context.mounted) {
                        context.push(
                          AppRouter.chat,
                          extra: {
                            'conversationId': convId,
                            'targetUserId': userId,
                            'targetUsername': username,
                            'targetAvatar': avatarUrl,
                          },
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error joining chat: $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF38EF7D,
                          ).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Iconsax.message_text_1,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMoments(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String username,
    String? avatarUrl,
  ) {
    context.push(
      AppRouter.userMoments,
      extra: {
        'user_id': userId,
        'username': username,
        'avatar_url': avatarUrl,
        'posts': posts,
      },
    );
  }

  void _showSafetyMenu(
    BuildContext context,
    String targetId,
    String targetName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 25),
              _buildSafetyOption(
                context,
                Iconsax.flag,
                'Report User',
                'Tell us if something is wrong with this user',
                Colors.orange,
                () {
                  Navigator.pop(context);
                  _showReportDialog(context, targetId, targetName);
                },
              ),
              const Divider(height: 1, indent: 70),
              _buildSafetyOption(
                context,
                Iconsax.slash,
                'Block User',
                'Stop seeing posts and messages from this user',
                Colors.red,
                () async {
                  Navigator.pop(context);
                  await SocialService.blockUser(targetId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$targetName has been blocked')),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyOption(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  void _showReportDialog(
    BuildContext context,
    String targetId,
    String targetName,
  ) {
    final reasons = [
      'Inappropriate Content',
      'Harassment',
      'Spam',
      'Fake Account',
      'Other',
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Report $targetName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () async {
                    Navigator.pop(context);
                    await SocialService.reportUser(
                      targetId: targetId,
                      reason: reason,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Report submitted. Thank you for keeping Livo safe!',
                          ),
                        ),
                      );
                    }
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBadgeWidget(UserBadgeModel badge) {
    return UserBadgeChip(badge: badge);
  }
}
