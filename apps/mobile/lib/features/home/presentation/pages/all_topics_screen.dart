import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/router/app_router.dart';

class AllTopicsScreen extends ConsumerWidget {
  const AllTopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTopicsAsync = ref.watch(allTopicsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'All Topics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: allTopicsAsync.when(
        data: (topics) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return GestureDetector(
              onTap: () => context.push(
                AppRouter.topicPosts,
                extra: {'topicId': topic['id'], 'topicName': topic['name']},
              ),
              child: _buildTopicCard(topic),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E5F6), Color(0xFFFCE4EC)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: AppColors.primaryUltraLight, width: 0.5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.primaryUltraLight.withOpacity(0.5),
              child: CachedNetworkImage(
                imageUrl: topic['icon_url'] ?? '',
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(
                  Iconsax.hashtag,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  topic['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${topic['new_posts_count']} posts',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
