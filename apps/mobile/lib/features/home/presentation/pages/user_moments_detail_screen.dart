import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserMomentsDetailScreen extends ConsumerWidget {
  final String userId;
  final String username;
  final String? avatarUrl;
  final List<Map<String, dynamic>> posts;

  const UserMomentsDetailScreen({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.posts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactions = ref.watch(socialInteractionProvider);

    final totalLikes = posts.fold<int>(0, (sum, p) {
      final postId = p['id'];
      final optLikeCount =
          (interactions['count_$postId'] as int?) ??
          (p['likes_count'] as int? ?? 0);
      return sum + optLikeCount;
    });

    final totalComments = posts.fold<int>(0, (sum, p) {
      final postId = p['id'];
      final optCommentCount =
          (interactions['ccount_$postId'] as int?) ??
          (p['comments_count'] as int? ?? 0);
      return sum + optCommentCount;
    });

    final isFollowedInDB =
        posts.isNotEmpty && posts.first['is_followed'] == true;
    final isFollowed =
        (interactions['follow_$userId'] as bool?) ?? isFollowedInDB;

    final allMedia = <Map<String, dynamic>>[];
    final postIds = <String>[];
    for (var p in posts) {
      final id = p['id']?.toString() ?? '';
      if (id.isNotEmpty) postIds.add(id);

      final images = p['image_urls'] as List? ?? [];
      if (images.isNotEmpty) {
        for (var img in images) {
          allMedia.add({'url': img, 'post': p});
        }
      } else {
        allMedia.add({'text': p['content_text'], 'post': p});
      }
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            '$username\'s Moments',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final frameAsync = ref.watch(
                        userEquippedFrameProvider(userId),
                      );
                      return SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: avatarUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: avatarUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 30,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
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
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: badges
                                      .map((badge) => _buildBadgeWidget(badge))
                                      .toList(),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (e, s) => const SizedBox.shrink(),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${posts.length} Posts • $totalLikes Likes',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await HapticFeedback.lightImpact();
                      await SocialService.toggleFollow(ref, userId, isFollowed);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowed
                          ? Colors.white
                          : AppColors.primary,
                      foregroundColor: isFollowed
                          ? AppColors.primary
                          : Colors.white,
                      elevation: 0,
                      side: isFollowed
                          ? BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(isFollowed ? 'Following' : 'Follow'),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Iconsax.like_1,
                    totalLikes.toString(),
                    'Total Likes',
                  ),
                  Container(width: 1, height: 30, color: AppColors.border),
                  _buildStatItem(
                    Iconsax.message_text_1,
                    totalComments.toString(),
                    'Total Comments',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: 'Moments'),
                Tab(text: 'Activity'),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  _buildMomentsGrid(allMedia),

                  _buildActivityFeed(ref, postIds),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentsGrid(List<Map<String, dynamic>> media) {
    if (media.isEmpty) {
      return const Center(child: Text('No moments yet.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final item = media[index];
        return GestureDetector(
          onTap: () => context.push(AppRouter.postDetail, extra: item['post']),
          child: Container(
            decoration: BoxDecoration(color: AppColors.primaryUltraLight),
            child: item['url'] != null
                ? CachedNetworkImage(
                    imageUrl: item['url'],
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppColors.background),
                    errorWidget: (context, url, err) => const Icon(Icons.error),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        item['text'] ?? '',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActivityFeed(WidgetRef ref, List<String> postIds) {
    final commentsAsync = ref.watch(userAllCommentsProvider(postIds.join(',')));

    return commentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.message,
                  size: 50,
                  color: AppColors.textHint.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No recent activity found.',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: comments.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 32, color: AppColors.border),
          itemBuilder: (context, index) {
            final comment = comments[index];
            final cUser = comment['user'] as Map<String, dynamic>?;
            final postId = comment['post_id'];

            final originalPost = posts.firstWhere(
              (p) => p['id'] == postId,
              orElse: () => {},
            );

            return GestureDetector(
              onTap: () =>
                  context.push(AppRouter.postDetail, extra: originalPost),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: cUser?['avatar_url'] != null
                        ? CachedNetworkImageProvider(cUser!['avatar_url'])
                        : null,
                    child: cUser?['avatar_url'] == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: '${cUser?['username'] ?? 'User'} ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: 'commented:'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment['content'] ?? '',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timeago.format(DateTime.parse(comment['created_at'])),
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (originalPost['image_urls'] != null &&
                      (originalPost['image_urls'] as List).isNotEmpty)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            (originalPost['image_urls'] as List).first,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading activity: $err')),
    );
  }

  Widget _buildStatItem(IconData icon, String count, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
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
