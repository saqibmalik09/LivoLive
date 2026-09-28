import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/widgets/user_moment_card.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class TopicPostsScreen extends ConsumerWidget {
  final String topicId;
  final String topicName;

  const TopicPostsScreen({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicAsync = ref.watch(topicDetailsProvider(topicId));
    final postsAsync = ref.watch(topicPostsProvider(topicId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: topicAsync.when(
          data: (topic) => _buildMainContent(context, ref, topic, postsAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => asyncErrorWidget(err),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 54,
          margin: const EdgeInsets.only(bottom: 10),
          child: ElevatedButton(
            onPressed: () => context.push(
              AppRouter.createPost,
              extra: {'topic_id': topicId, 'topic_name': topicName},
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD600),
              foregroundColor: AppColors.textPrimary,
              elevation: 8,
              shadowColor: const Color(0xFFFFD600).withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
            ),
            child: const Text(
              'Participate topics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? topic,
    AsyncValue<List<Map<String, dynamic>>> postsAsync,
  ) {
    final bannerUrl = topic?['banner_url'];
    final description =
        topic?['description'] ??
        'Participate in the "$topicName" event and share your moments!';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(topicDetailsProvider(topicId));
        ref.invalidate(topicPostsProvider(topicId));
      },
      color: AppColors.primary,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 260,
                width: double.infinity,
                color: AppColors.primary,
                child: bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.primary,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.primary,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white54,
                            size: 40,
                          ),
                        ),
                      )
                    : null,
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: -1,
                left: 0,
                right: 0,
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Color(0xFFFFD600),
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Popular'),
              Tab(text: 'latest'),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [
                _buildPostsList(postsAsync, isPopular: true),
                _buildPostsList(postsAsync, isPopular: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(
    AsyncValue<List<Map<String, dynamic>>> postsAsync, {
    required bool isPopular,
  }) {
    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        final List<Map<String, dynamic>> sortedPosts = List.from(posts);
        if (isPopular) {
          sortedPosts.sort(
            (a, b) =>
                (b['likes_count'] as int).compareTo(a['likes_count'] as int),
          );
        } else {
          sortedPosts.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
        }

        final Map<String, List<Map<String, dynamic>>> groupedPosts = {};
        final Set<String> seenUsers = {};
        for (var post in sortedPosts) {
          final userId = post['user_id']?.toString();
          if (userId != null && !seenUsers.contains(userId)) {
            groupedPosts[userId] = [post];
            seenUsers.add(userId);
          }
        }

        final users = groupedPosts.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userId = users[index];
            final userPosts = groupedPosts[userId]!;
            final userData = userPosts.first['user'] as Map<String, dynamic>?;

            return UserMomentCard(user: userData, posts: userPosts);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => asyncErrorWidget(err),
    );
  }
}
