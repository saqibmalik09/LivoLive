import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/widgets/follow_relationship_button.dart';

class SocialDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final int initialTabIndex;

  const SocialDetailScreen({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<SocialDetailScreen> createState() => _SocialDetailScreenState();
}

class _SocialDetailScreenState extends ConsumerState<SocialDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0108),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2E0219).withValues(alpha: 0.8),
              const Color(0xFF0F0108),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFollowingTab(),
                    _buildFollowersTab(),
                    _buildCharmTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Text(
            'Social Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFFFF69B4)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Following'),
          Tab(text: 'Followers'),
          Tab(text: 'Charm'),
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
    final followingAsync = ref.watch(followingListProvider(widget.userId));
    return followingAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, st) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (users) => users.isEmpty
          ? _buildEmptyState('No following found')
          : _buildUserList(users),
    );
  }

  Widget _buildFollowersTab() {
    final followersAsync = ref.watch(followersListProvider(widget.userId));
    return followersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, st) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (users) => users.isEmpty
          ? _buildEmptyState('No followers found')
          : _buildUserList(users),
    );
  }

  Widget _buildCharmTab() {
    final contributorsAsync = ref.watch(
      charmContributorsProvider(widget.userId),
    );
    return contributorsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, st) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (users) => users.isEmpty
          ? _buildEmptyState('No contributors yet')
          : _buildContributorList(users),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.user_tag, size: 60, color: Colors.white12),
          const SizedBox(height: 15),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () => NavigationUtils.navigateToProfile(context, ref, user['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            _buildAvatar(user['avatar_url'], user['username']),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['username'] ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLevelBadge(user['user_level'] ?? 1, AppColors.gold),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['bio'] ?? 'LIVO Enthusiast',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            _buildFollowButton(user['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildContributorList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildContributorTile(user, index + 1);
      },
    );
  }

  Widget _buildContributorTile(Map<String, dynamic> user, int rank) {
    return GestureDetector(
      onTap: () => NavigationUtils.navigateToProfile(context, ref, user['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: rank <= 3
                ? AppColors.gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 25,
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3 ? AppColors.gold : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 5),
            _buildAvatar(user['avatar_url'], user['username']),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['username'] ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildLevelBadge(
                        user['wealth_level'] ?? 1,
                        Colors.purpleAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.heart_copy,
                      color: AppColors.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${user['total_amount']}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Contribution',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, String? name) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.white10),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.person, color: Colors.white24),
              )
            : const Icon(Icons.person, color: Colors.white24),
      ),
    );
  }

  Widget _buildLevelBadge(int level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        'Lv.$level',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFollowButton(String targetId) {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == targetId) return const SizedBox.shrink();

    return FollowRelationshipButton(
      targetUserId: targetId,
      onDarkBackground: true,
    );
  }
}
