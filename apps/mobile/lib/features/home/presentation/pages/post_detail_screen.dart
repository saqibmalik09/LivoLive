import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/social_provider.dart';

import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';

class PostDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postId = post['id'];

    final postsAsync = ref.watch(postsProvider);

    final currentPost = postsAsync.when(
      data: (posts) =>
          posts.firstWhere((p) => p['id'] == postId, orElse: () => post),
      loading: () => post,
      error: (_, _) => post,
    );

    final userId =
        (currentPost['user_id'] ?? currentPost['author_id'])?.toString() ??
        'unknown';
    final user = currentPost['user'] as Map<String, dynamic>?;
    final username = user?['username'] ?? context.l10n.common_user;
    final avatarUrl = user?['avatar_url'];
    final images = (currentPost['image_urls'] as List?)?.cast<String>() ?? [];

    final bool isLiked = currentPost['is_liked'] == true;
    final bool isFollowed = currentPost['is_followed'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          context.l10n.social_postDetails,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        NavigationUtils.navigateToProfile(context, ref, userId),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final frameAsync = ref.watch(
                          userEquippedFrameProvider(userId),
                        );
                        return SizedBox(
                          width: 60,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => NavigationUtils.navigateToProfile(
                            context,
                            ref,
                            userId,
                          ),
                          child: Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Consumer(
                          builder: (context, ref, child) {
                            final badgesAsync = ref.watch(
                              userBadgesProvider(userId),
                            );
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
                                      '• ${currentPost['created_at'] != null ? timeago.format(DateTime.parse(currentPost['created_at'])) : context.l10n.social_justNow}',
                                      style: const TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              },
                              loading: () => Text(
                                '• ${currentPost['created_at'] != null ? timeago.format(DateTime.parse(currentPost['created_at'])) : context.l10n.social_justNow}',
                                style: const TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                              error: (e, s) => Text(
                                '• ${currentPost['created_at'] != null ? timeago.format(DateTime.parse(currentPost['created_at'])) : context.l10n.social_justNow}',
                                style: const TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showSafetyMenu(
                      context,
                      user?['id']?.toString() ?? '',
                      username,
                    ),
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: () async {
                      final targetId = currentPost['author_id'];
                      debugPrint(
                        'UI_DEBUG: Follow button tapped on Detail screen. Target: $targetId',
                      );

                      if (targetId != null) {
                        await HapticFeedback.lightImpact();
                        await SocialService.toggleFollow(
                          ref,
                          targetId.toString(),
                          isFollowed,
                        );
                      } else {
                        debugPrint(
                          'UI_DEBUG: Cannot follow, target author_id is NULL',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowed
                          ? Colors.white
                          : AppColors.primaryUltraLight,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      side: isFollowed
                          ? BorderSide(
                              color: AppColors.primary.withOpacity(0.3),
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      isFollowed ? 'Following' : 'Follow',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (currentPost['content_text'] != null &&
                  currentPost['content_text'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    currentPost['content_text'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),

              if (images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: images[0],
                    width: double.infinity,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: AppColors.shimmerBase,
                      highlightColor: AppColors.shimmerHighlight,
                      child: Container(height: 300, color: Colors.white),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 24),

              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await HapticFeedback.lightImpact();
                      debugPrint('SOCIAL_DEBUG: Like tapped for post: $postId');
                      await SocialService.toggleLike(
                        ref,
                        postId,
                        currentPost['likes_count'] as int? ?? 0,
                        isLiked,
                      );
                    },
                    child: _buildInteractionItem(
                      Iconsax.like_1,
                      '${currentPost['likes_count']}',
                      isLiked ? Colors.red : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showCommentSheet(
                      context,
                      ref,
                      postId,
                      currentPost['comments_count'] as int? ?? 0,
                    ),
                    child: _buildInteractionItem(
                      Iconsax.message_text_1,
                      '${currentPost['comments_count']}',
                      AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  _buildChatButton(),
                ],
              ),

              const SizedBox(height: 32),
              const Divider(height: 1),
              const SizedBox(height: 24),

              Text(
                context.l10n.social_comments,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              ref
                  .watch(postCommentsProvider(postId))
                  .when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final commentId = comment['id']?.toString() ?? '';
                          final cUser =
                              comment['user'] as Map<String, dynamic>?;
                          final cUsername =
                              cUser?['username'] ?? context.l10n.common_user;
                          final cAvatar = cUser?['avatar_url'];
                          final cLevel = cUser?['user_level'] ?? 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => NavigationUtils.navigateToProfile(
                                  context,
                                  ref,
                                  comment['user_id']?.toString() ?? '',
                                ),
                                child: Consumer(
                                  builder: (context, ref, child) {
                                    final cUserId =
                                        comment['user_id']?.toString() ?? '';
                                    final frameAsync = ref.watch(
                                      userEquippedFrameProvider(cUserId),
                                    );
                                    return SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                            ),
                                            child: ClipOval(
                                              child: cAvatar != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: cAvatar,
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
                                                  frame['image_url'] ??
                                                  frame['svga_url'];
                                              if (frameUrl == null)
                                                return const SizedBox.shrink();

                                              return Positioned.fill(
                                                child: IgnorePointer(
                                                  child:
                                                      (frame['svga_url'] !=
                                                              null &&
                                                          frame['svga_url']!
                                                              .isNotEmpty)
                                                      ? RaveSVGAPlayer(
                                                          resUrl:
                                                              frame['svga_url']!,
                                                          fit: BoxFit.fill,
                                                        )
                                                      : CachedNetworkImage(
                                                          imageUrl:
                                                              frame['image_url']!,
                                                          fit: BoxFit.fill,
                                                        ),
                                                ),
                                              );
                                            },
                                            loading: () =>
                                                const SizedBox.shrink(),
                                            error: (e, s) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Consumer(
                                            builder: (context, ref, child) {
                                              final cUserId =
                                                  comment['user_id']
                                                      ?.toString() ??
                                                  '';
                                              final badgesAsync = ref.watch(
                                                userBadgesProvider(cUserId),
                                              );

                                              return Wrap(
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    cUsername,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  ...badgesAsync.when(
                                                    data: (badges) => badges
                                                        .map(
                                                          (badge) =>
                                                              _buildBadgeWidget(
                                                                badge,
                                                                scale: 0.7,
                                                              ),
                                                        )
                                                        .toList(),
                                                    loading: () => [],
                                                    error: (e, s) => [],
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () async {
                                            await HapticFeedback.lightImpact();
                                            await SocialService.toggleCommentLike(
                                              ref,
                                              commentId,
                                              comment['likes_count'] as int? ??
                                                  0,
                                              comment['is_liked'] == true,
                                            );
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                comment['is_liked'] == true
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                size: 14,
                                                color:
                                                    comment['is_liked'] == true
                                                    ? Colors.red
                                                    : AppColors.textHint,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${comment['likes_count'] ?? 0}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      comment['is_liked'] ==
                                                          true
                                                      ? Colors.red
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['content'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error loading comments: $err'),
                  ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractionItem(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 6),
        Text(
          count,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChatButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38EF7D).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.message_text_1, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Chat',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentSheet(
    BuildContext context,
    WidgetRef ref,
    String postId,
    int currentCount,
  ) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Comment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Write your comment...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    await SocialService.addComment(
                      ref,
                      postId,
                      currentCount,
                      controller.text,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Post Comment',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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

  Widget _buildBadgeWidget(UserBadgeModel badge, {double scale = 1.0}) {
    return UserBadgeChip(
      badge: badge,
      height:
          (badge.type == 'medal'
              ? 20
              : (badge.type == 'vip'
                    ? 12
                    : (badge.type == 'agency' ? 16 : 18))) *
          scale,
    );
  }
}
