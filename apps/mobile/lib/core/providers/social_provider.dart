import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'package:sk_live/core/services/task_tracker_service.dart';

final supabase = Supabase.instance.client;

final topicsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return realtimeWithFallback<List<Map<String, dynamic>>>(
    fetch: () async {
      final rows = await supabase
          .from('topics')
          .select()
          .eq('is_featured', true)
          .order('new_posts_count', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    },
    realtime: () => supabase
        .from('topics')
        .stream(primaryKey: ['id'])
        .eq('is_featured', true)
        .order('new_posts_count', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data)),
  );
});

final allTopicsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return realtimeWithFallback<List<Map<String, dynamic>>>(
    fetch: () async {
      final rows = await supabase
          .from('topics')
          .select()
          .order('new_posts_count', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    },
    realtime: () => supabase
        .from('topics')
        .stream(primaryKey: ['id'])
        .order('new_posts_count', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data)),
  );
});

final socialInteractionProvider = StateProvider<Map<String, dynamic>>(
  (ref) => {},
);

final popularPostsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
        .from('posts')
        .select(
          '*, user:user_id(id, username, avatar_url, user_level), topic:topic_id(name), post_likes(user_id)',
        );

    final posts = List<Map<String, dynamic>>.from(response);
    final interactions = ref.watch(socialInteractionProvider);

    List<String> followedIds = [];
    if (userId != null) {
      final followsRes = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      followedIds = (followsRes as List)
          .map((f) => f['following_id'].toString())
          .toList();
    }

    final processedPosts = posts.map((post) {
      final postId = post['id'];
      final likes = post['post_likes'] as List? ?? [];
      final authorData = post['user'] as Map<String, dynamic>?;
      final postAuthorId =
          authorData?['id']?.toString() ?? post['user_id']?.toString();

      bool isLiked = userId != null && likes.any((l) => l['user_id'] == userId);
      if (interactions.containsKey('like_$postId'))
        isLiked = interactions['like_$postId'];

      int likesCount = post['likes_count'] as int? ?? 0;
      if (interactions.containsKey('count_$postId'))
        likesCount = interactions['count_$postId'];

      bool isFollowed = followedIds.contains(postAuthorId);
      if (interactions.containsKey('follow_$postAuthorId'))
        isFollowed = interactions['follow_$postAuthorId'];

      int commentsCount = post['comments_count'] as int? ?? 0;
      if (interactions.containsKey('ccount_$postId'))
        commentsCount = interactions['ccount_$postId'];

      return {
        ...post,
        'author_id': postAuthorId,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'is_liked': isLiked,
        'is_followed': isFollowed,
        'total_engagement': likesCount + commentsCount,
      };
    }).toList();

    processedPosts.sort(
      (a, b) => (b['total_engagement'] as int).compareTo(
        a['total_engagement'] as int,
      ),
    );
    return processedPosts;
  } catch (e) {
    debugPrint('SOCIAL_DEBUG: Error in popularPostsProvider: $e');
    return [];
  }
});

final latestPostsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase
        .from('posts')
        .select(
          '*, user:user_id(id, username, avatar_url, user_level), topic:topic_id(name), post_likes(user_id)',
        );

    final posts = List<Map<String, dynamic>>.from(response);
    final interactions = ref.watch(socialInteractionProvider);

    List<String> followedIds = [];
    if (userId != null) {
      final followsRes = await supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      followedIds = (followsRes as List)
          .map((f) => f['following_id'].toString())
          .toList();
    }

    final processedPosts = posts.map((post) {
      final postId = post['id'];
      final likes = post['post_likes'] as List? ?? [];
      final authorData = post['user'] as Map<String, dynamic>?;
      final postAuthorId =
          authorData?['id']?.toString() ?? post['user_id']?.toString();

      bool isLiked = userId != null && likes.any((l) => l['user_id'] == userId);
      if (interactions.containsKey('like_$postId'))
        isLiked = interactions['like_$postId'];

      int likesCount = post['likes_count'] as int? ?? 0;
      if (interactions.containsKey('count_$postId'))
        likesCount = interactions['count_$postId'];

      bool isFollowed = followedIds.contains(postAuthorId);
      if (interactions.containsKey('follow_$postAuthorId'))
        isFollowed = interactions['follow_$postAuthorId'];

      return {
        ...post,
        'author_id': postAuthorId,
        'likes_count': likesCount,
        'comments_count': post['comments_count'] as int? ?? 0,
        'is_liked': isLiked,
        'is_followed': isFollowed,
      };
    }).toList();

    processedPosts.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return processedPosts;
  } catch (e) {
    return [];
  }
});

final topicDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, topicId) async {
      try {
        final response = await supabase
            .from('topics')
            .select('*')
            .eq('id', topicId)
            .maybeSingle();
        return response;
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: Error fetching topic details: $e');
        return null;
      }
    });

final postsProvider = latestPostsProvider;

final topicPostsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      topicId,
    ) async {
      try {
        final userId = supabase.auth.currentUser?.id;
        final response = await supabase
            .from('posts')
            .select(
              '*, user:user_id(id, username, avatar_url, user_level), topic:topic_id(name), post_likes(user_id)',
            )
            .eq('topic_id', topicId);

        final posts = List<Map<String, dynamic>>.from(response);

        List<String> followedIds = [];
        if (userId != null) {
          final followsRes = await supabase
              .from('follows')
              .select('following_id')
              .eq('follower_id', userId);
          followedIds = (followsRes as List)
              .map((f) => f['following_id'].toString())
              .toList();
        }

        final interactions = ref.watch(socialInteractionProvider);

        final processedPosts = posts.map((post) {
          final postId = post['id'];
          final likes = post['post_likes'] as List? ?? [];
          final authorData = post['user'] as Map<String, dynamic>?;
          final postAuthorId =
              authorData?['id']?.toString() ?? post['user_id']?.toString();

          bool isLiked =
              userId != null && likes.any((l) => l['user_id'] == userId);
          if (interactions.containsKey('like_$postId'))
            isLiked = interactions['like_$postId'];

          int likesCount = post['likes_count'] as int? ?? 0;
          if (interactions.containsKey('count_$postId'))
            likesCount = interactions['count_$postId'];

          bool isFollowed = followedIds.contains(postAuthorId);
          if (interactions.containsKey('follow_$postAuthorId'))
            isFollowed = interactions['follow_$postAuthorId'];

          int commentsCount = post['comments_count'] as int? ?? 0;
          if (interactions.containsKey('ccount_$postId'))
            commentsCount = interactions['ccount_$postId'];

          return {
            ...post,
            'author_id': postAuthorId,
            'likes_count': likesCount,
            'comments_count': commentsCount,
            'is_liked': isLiked,
            'is_followed': isFollowed,
          };
        }).toList();

        processedPosts.sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
        return processedPosts;
      } catch (e, stack) {
        debugPrint('SOCIAL_DEBUG: Error in topicPostsProvider: $e\n$stack');
        rethrow;
      }
    });

final followingPostsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final followsRes = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final followedIds = (followsRes as List)
        .map((f) => f['following_id'].toString())
        .toList();

    if (followedIds.isEmpty) return [];

    final response = await supabase
        .from('posts')
        .select(
          '*, user:user_id(id, username, avatar_url, user_level), topic:topic_id(name), post_likes(user_id)',
        )
        .inFilter('user_id', followedIds);

    final posts = List<Map<String, dynamic>>.from(response);
    final interactions = ref.watch(socialInteractionProvider);

    final processedPosts = posts.map((post) {
      final postId = post['id'];
      final likes = post['post_likes'] as List? ?? [];
      final authorData = post['user'] as Map<String, dynamic>?;
      final postAuthorId =
          authorData?['id']?.toString() ?? post['user_id']?.toString();

      bool isLiked = likes.any((l) => l['user_id'] == userId);
      if (interactions.containsKey('like_$postId'))
        isLiked = interactions['like_$postId'];

      int likesCount = post['likes_count'] as int? ?? 0;
      if (interactions.containsKey('count_$postId'))
        likesCount = interactions['count_$postId'];

      bool isFollowed = true;
      if (interactions.containsKey('follow_$postAuthorId'))
        isFollowed = interactions['follow_$postAuthorId'];

      int commentsCount = post['comments_count'] as int? ?? 0;
      if (interactions.containsKey('ccount_$postId'))
        commentsCount = interactions['ccount_$postId'];

      return {
        ...post,
        'author_id': postAuthorId,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'is_liked': isLiked,
        'is_followed': isFollowed,
      };
    }).toList();

    processedPosts.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return processedPosts;
  } catch (e) {
    debugPrint('SOCIAL_DEBUG: Error in followingPostsProvider: $e');
    return [];
  }
});

final mutualFriendsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final iFollowResponse = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final iFollowSet = (iFollowResponse as List)
        .map((f) => f['following_id'].toString())
        .toSet();

    final followMeResponse = await supabase
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);
    final followMeSet = (followMeResponse as List)
        .map((f) => f['follower_id'].toString())
        .toSet();

    final mutualIds = iFollowSet.intersection(followMeSet).toList();

    debugPrint(
      'SOCIAL_DEBUG: Found ${mutualIds.length} mutual friends for $userId',
    );
    return mutualIds;
  } catch (e) {
    debugPrint('SOCIAL_DEBUG: Error fetching mutual friends: $e');
    return [];
  }
});

final localCommentsProvider =
    StateProvider.family<List<Map<String, dynamic>>, String>(
      (ref, postId) => [],
    );

final postCommentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      postId,
    ) async {
      final userId = supabase.auth.currentUser?.id;
      final interactions = ref.watch(socialInteractionProvider);

      debugPrint('SOCIAL_DEBUG: [FETCH_COMMENTS] For Post ID: $postId');

      try {
        final response = await supabase
            .from('comments')
            .select(
              '*, user:user_id(username, avatar_url, user_level), comment_likes(user_id)',
            )
            .eq('post_id', postId)
            .order('created_at', ascending: true);

        final List<Map<String, dynamic>> rawComments =
            List<Map<String, dynamic>>.from(response);

        final serverComments = rawComments
            .where((c) => c['post_id'] == postId)
            .toList();

        final processedComments = serverComments.map((c) {
          final commentId = c['id'];
          final cLikes = c['comment_likes'] as List? ?? [];

          bool isLiked =
              userId != null && cLikes.any((l) => l['user_id'] == userId);
          if (interactions.containsKey('clike_$commentId')) {
            isLiked = interactions['clike_$commentId'];
          }

          int likesCount = c['likes_count'] as int? ?? 0;
          if (interactions.containsKey('c_count_$commentId')) {
            likesCount = interactions['c_count_$commentId'];
          }

          return {...c, 'is_liked': isLiked, 'likes_count': likesCount};
        }).toList();

        final localComments = ref.watch(localCommentsProvider(postId));
        return [...processedComments, ...localComments];
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: [ERROR] Fetching comments for $postId: $e');
        return [];
      }
    });

final userAllCommentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      postIdsStr,
    ) async {
      if (postIdsStr.isEmpty) return [];

      final postIds = postIdsStr
          .split(',')
          .where((id) => id.isNotEmpty)
          .toList();
      if (postIds.isEmpty) return [];

      try {
        final response = await supabase
            .from('comments')
            .select('*, user:user_id(username, avatar_url, user_level)')
            .inFilter('post_id', postIds)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: [ERROR] Bulk fetching comments: $e');
        return [];
      }
    });

class SocialService {
  static Future<void> toggleLike(
    WidgetRef ref,
    String postId,
    int currentCount,
    bool currentlyLiked,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final newLiked = !currentlyLiked;
    final newCount = newLiked ? currentCount + 1 : currentCount - 1;

    ref
        .read(socialInteractionProvider.notifier)
        .update(
          (state) => {
            ...state,
            'like_$postId': newLiked,
            'count_$postId': newCount,
          },
        );

    debugPrint(
      'SOCIAL_DEBUG: [OPTIMISTIC] Like toggled to $newLiked, count: $newCount',
    );

    try {
      if (currentlyLiked) {
        await supabase
            .from('post_likes')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', postId);
      } else {
        await supabase.from('post_likes').insert({
          'user_id': userId,
          'post_id': postId,
        });
      }
      debugPrint('SOCIAL_DEBUG: [SUCCESS] DB updated for Like.');
    } catch (e) {
      debugPrint(
        'SOCIAL_DEBUG: [REVERT] Like failed, rolling back local state: $e',
      );
    } finally {
      ref.invalidate(postsProvider);
    }
  }

  static Future<void> toggleCommentLike(
    WidgetRef ref,
    String commentId,
    int currentCount,
    bool currentlyLiked,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final newLiked = !currentlyLiked;
    final newCount = newLiked ? currentCount + 1 : currentCount - 1;

    ref
        .read(socialInteractionProvider.notifier)
        .update(
          (state) => {
            ...state,
            'clike_$commentId': newLiked,
            'c_count_$commentId': newCount,
          },
        );

    try {
      if (currentlyLiked) {
        await supabase
            .from('comment_likes')
            .delete()
            .eq('user_id', userId)
            .eq('comment_id', commentId);
      } else {
        await supabase.from('comment_likes').insert({
          'user_id': userId,
          'comment_id': commentId,
        });
      }
    } catch (e) {
      debugPrint('SOCIAL_DEBUG: Comment Like failed: $e');
    }
  }

  static Future<void> toggleFollow(
    WidgetRef ref,
    String targetUserId,
    bool currentlyFollowed,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    debugPrint('SOCIAL_DEBUG: My ID: $userId | Target: $targetUserId');

    if (userId == null) {
      debugPrint('SOCIAL_DEBUG: Follow failed (User not logged in).');
      return;
    }

    if (userId == targetUserId) {
      debugPrint('SOCIAL_DEBUG: Follow ignored (Cannot follow yourself!).');
      return;
    }

    final newFollowed = !currentlyFollowed;
    ref
        .read(socialInteractionProvider.notifier)
        .update((state) => {...state, 'follow_$targetUserId': newFollowed});

    debugPrint('SOCIAL_DEBUG: [OPTIMISTIC] Follow toggled to $newFollowed');

    debugPrint(
      'SOCIAL_DEBUG: [START_FOLLOW] From: $userId | To: $targetUserId',
    );

    try {
      if (currentlyFollowed) {
        debugPrint('SOCIAL_DEBUG: [DB_REQ] Deleting follow record...');
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', userId)
            .eq('following_id', targetUserId);
        debugPrint('SOCIAL_DEBUG: [DB_RES] Unfollow request sent.');
      } else {
        debugPrint('SOCIAL_DEBUG: [DB_REQ] Inserting follow record...');
        await supabase.from('follows').insert({
          'follower_id': userId,
          'following_id': targetUserId,
        });
        debugPrint('SOCIAL_DEBUG: [DB_RES] Follow request sent.');
        await TaskTrackerService.trackAction('newbie_follow_3');
      }

      final verifyRes = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .eq('following_id', targetUserId);

      final exists = (verifyRes as List).isNotEmpty;
      debugPrint('SOCIAL_DEBUG: [VERIFIED] Follow exists in DB now: $exists');
    } catch (e) {
      debugPrint('SOCIAL_DEBUG: [CRITICAL_ERROR] Follow/Unfollow Failed: $e');
    } finally {
      ref.invalidate(postsProvider);
      ref.invalidate(mutualFriendsProvider);
      ref.invalidate(followRelationshipProvider(targetUserId));
      ref.invalidate(isFollowingProvider(targetUserId));
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        ref.invalidate(followingListProvider(currentUserId));
        ref.invalidate(followersListProvider(currentUserId));
      }
      ref.invalidate(followingListProvider(targetUserId));
      ref.invalidate(followersListProvider(targetUserId));
    }
  }

  static Future<void> addComment(
    WidgetRef ref,
    String postId,
    int currentCount,
    String content,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || content.trim().isEmpty) return;

    final tempComment = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'content': content.trim(),
      'created_at': DateTime.now().toIso8601String(),
      'user': {'username': 'You', 'avatar_url': null, 'user_level': 1},
    };

    ref
        .read(localCommentsProvider(postId).notifier)
        .update((state) => [...state, tempComment]);

    final newCount = currentCount + 1;
    ref
        .read(socialInteractionProvider.notifier)
        .update((state) => {...state, 'ccount_$postId': newCount});

    debugPrint(
      'SOCIAL_DEBUG: [OPTIMISTIC] Comment added locally, count incremented to $newCount.',
    );

    try {
      await supabase.from('comments').insert({
        'user_id': userId,
        'post_id': postId,
        'content': content.trim(),
      });
      debugPrint('SOCIAL_DEBUG: [SUCCESS] Comment saved to DB.');

      await TaskTrackerService.trackAction('comment_trends');

      ref.read(localCommentsProvider(postId).notifier).state = [];
      ref.invalidate(postCommentsProvider(postId));
      ref.invalidate(postsProvider);
    } catch (e) {
      debugPrint('SOCIAL_DEBUG: [REVERT] Comment failed: $e');
      ref
          .read(localCommentsProvider(postId).notifier)
          .update(
            (state) =>
                state.where((c) => c['id'] != tempComment['id']).toList(),
          );
    }
  }

  static Future<void> reportUser({
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('user_reports').insert({
      'reporter_id': userId,
      'target_id': targetId,
      'reason': reason,
      'details': details,
    });
  }

  static Future<void> blockUser(String targetId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final targetProfile = await supabase
          .from('users')
          .select('vip_level')
          .eq('id', targetId)
          .single();

      final int vipLevel = (targetProfile['vip_level'] as num?)?.toInt() ?? 0;
      if (vipLevel > 0) {
        final vipPlan = await supabase
            .from('vip_plans')
            .select('has_anti_blocking')
            .eq('level', vipLevel)
            .maybeSingle();
        if (vipPlan != null && vipPlan['has_anti_blocking'] == true) {
          throw 'This user is protected by Anti-Blocking privilege.';
        }
      }

      final ids = [userId, targetId]..sort();
      final response = await supabase
          .from('conversations')
          .select('id')
          .eq('participant_1_id', ids[0])
          .eq('participant_2_id', ids[1])
          .maybeSingle();

      if (response != null) {
        await supabase
            .from('conversations')
            .update({'status': 'blocked'})
            .eq('id', response['id']);
      } else {
        await supabase.from('conversations').insert({
          'participant_1_id': ids[0],
          'participant_2_id': ids[1],
          'status': 'blocked',
        });
      }
    } catch (e) {
      debugPrint('SOCIAL_DEBUG: Block user error: $e');
    }
  }
}

final followingListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      try {
        final response = await supabase
            .from('follows')
            .select(
              'following_id, users:following_id(id, username, avatar_url, user_level, wealth_level, bio)',
            )
            .eq('follower_id', userId);

        return (response as List)
            .map((f) => f['users'] as Map<String, dynamic>)
            .toList();
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: Error fetching following list: $e');
        return [];
      }
    });

final followersListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      try {
        final response = await supabase
            .from('follows')
            .select(
              'follower_id, users:follower_id(id, username, avatar_url, user_level, wealth_level, bio)',
            )
            .eq('following_id', userId);

        return (response as List)
            .map((f) => f['users'] as Map<String, dynamic>)
            .toList();
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: Error fetching followers list: $e');
        return [];
      }
    });

final charmContributorsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      userId,
    ) async {
      try {
        final response = await supabase
            .from('gift_logs')
            .select(
              'sender_id, amount, users:sender_id(id, username, avatar_url, user_level, wealth_level)',
            )
            .eq('receiver_id', userId)
            .order('created_at', ascending: false);

        final logs = response as List;
        final Map<String, Map<String, dynamic>> contributors = {};

        for (var log in logs) {
          final senderId = log['sender_id'];
          final userData = log['users'] as Map<String, dynamic>;
          final amount = log['amount'] as int;

          if (contributors.containsKey(senderId)) {
            contributors[senderId]!['total_amount'] += amount;
          } else {
            contributors[senderId] = {...userData, 'total_amount': amount};
          }
        }

        final result = contributors.values.toList();
        result.sort(
          (a, b) =>
              (b['total_amount'] as int).compareTo(a['total_amount'] as int),
        );
        return result;
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: Error fetching charm contributors: $e');
        return [];
      }
    });

enum FollowRelationshipState { self, none, following, followBack, friends }

final followRelationshipProvider =
    FutureProvider.family<FollowRelationshipState, String>((
      ref,
      targetUserId,
    ) async {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return FollowRelationshipState.none;
      if (currentUserId == targetUserId) return FollowRelationshipState.self;

      try {
        final interactions = ref.watch(socialInteractionProvider);
        final optimistic = interactions['follow_$targetUserId'] as bool?;

        final iFollowRes = await supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUserId)
            .eq('following_id', targetUserId)
            .maybeSingle();

        final theyFollowRes = await supabase
            .from('follows')
            .select('id')
            .eq('follower_id', targetUserId)
            .eq('following_id', currentUserId)
            .maybeSingle();

        final iFollow = optimistic ?? (iFollowRes != null);
        final theyFollow = theyFollowRes != null;

        if (iFollow && theyFollow) return FollowRelationshipState.friends;
        if (iFollow) return FollowRelationshipState.following;
        if (theyFollow) return FollowRelationshipState.followBack;
        return FollowRelationshipState.none;
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: followRelationship error: $e');
        return FollowRelationshipState.none;
      }
    });

final isFollowingProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  targetUserId,
) async {
  cacheFamilyEntry(ref);
  final currentUserId = supabase.auth.currentUser?.id;
  if (currentUserId == null) return false;

  try {
    final response = await supabase
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    final bool dbFollowed = response != null;

    final interactions = ref.watch(socialInteractionProvider);
    if (interactions.containsKey('follow_$targetUserId')) {
      return interactions['follow_$targetUserId'];
    }

    return dbFollowed;
  } catch (e) {
    return false;
  }
});

final userSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
      cacheFamilyEntry(ref, ttl: const Duration(minutes: 2));
      final trimmed = query.trim();
      if (!isUserSearchQueryReady(trimmed)) return [];

      try {
        const select =
            'id, username, avatar_url, user_level, wealth_level, short_id';

        if (isNumericUidQuery(trimmed)) {
          final sid = int.parse(trimmed);
          final response = await supabase
              .from('users')
              .select(select)
              .eq('short_id', sid)
              .limit(5);
          return List<Map<String, dynamic>>.from(response);
        }

        final response = await supabase
            .from('users')
            .select(select)
            .ilike('username', '%$trimmed%')
            .limit(10);
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        debugPrint('SOCIAL_DEBUG: Error searching users: $e');
        return [];
      }
    });
