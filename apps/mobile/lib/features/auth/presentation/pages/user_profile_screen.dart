import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/display_user_id.dart';
import 'package:sk_live/core/widgets/follow_relationship_button.dart';
import 'package:sk_live/core/widgets/user_profile_active_room_strip.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_about_moment_tabs.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_achievement_row.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_badge_gallery.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_hero_header.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_relationship_card.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_screen_theme.dart';
import 'package:sk_live/features/auth/presentation/widgets/profile/profile_supporters_row.dart';
import 'package:sk_live/features/home/presentation/pages/cp_nest_screen.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _visitRecorded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_visitRecorded || !mounted) return;
      _visitRecorded = true;
      recordProfileVisit(widget.userId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isSelf {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    return currentId != null && currentId == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(publicUserProfileProvider(widget.userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: _GlassAppBarButton(
          icon: Iconsax.arrow_left_2,
          onPressed: () => context.pop(),
        ),
        actions: [
          _GlassAppBarButton(
            icon: Iconsax.share,
            onPressed: () {
              final user = userAsync.value;
              final username = user?['username'] ?? 'User';
              final displayId = displayUserId(
                user,
                fallback: widget.userId.substring(0, 8).toUpperCase(),
              );
              Share.share('Check out $username on SK Live! UID: $displayId');
            },
          ),
          if (_isSelf) ...[
            const SizedBox(width: 6),
            _GlassAppBarButton(
              icon: Iconsax.edit,
              onPressed: () => context.push(AppRouter.editProfile),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: ProfileScreenTheme.bgGradient,
        ),
        child: userAsync.when(
          data: (user) => user == null
              ? _buildError('User not found')
              : _buildProfile(user),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => _buildError(e.toString()),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserProfileActiveRoomStrip(userId: widget.userId),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildProfile(Map<String, dynamic> user) {
    final vipLevel = (user['vip_level'] as num?)?.toInt() ?? 0;
    final supporters = user['supporters'] as List? ?? [];
    final frames = user['frames'] as List? ?? [];
    final cars = user['cars'] as List? ?? [];
    final gifts = user['gifts'] as List? ?? [];

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: ProfileHeroHeader(
            userId: widget.userId,
            user: user,
            onStatTap: _navigateToSocial,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: ProfileTabBarDelegate(
            tabBar: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelColor: AppColors.primaryDark,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'About me'),
                Tab(text: 'My relationship'),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          ProfileAboutTab(
            supporters: ProfileSupportersRow(
              supporters: supporters,
              onViewAll: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GiftCenterScreen()),
              ),
            ),
            achievement: ProfileAchievementRow(
              userId: widget.userId,
              vipLevel: vipLevel,
              onVipTap: _isSelf
                  ? () => context.push(AppRouter.vipCenter)
                  : null,
            ),
            badgeGallery: ProfileBadgeGallery(
              userId: widget.userId,
              frames: frames,
              cars: cars,
              onViewAll: () => context.push(
                AppRouter.inventory,
                extra: {'userId': widget.userId, 'tab': 'frames'},
              ),
            ),
            giftWall: ProfileGiftInventoryStrip(
              gifts: gifts,
              onViewAll: () => context.push(
                AppRouter.inventory,
                extra: {'userId': widget.userId, 'tab': 'gifts'},
              ),
            ),
          ),
          ProfileRelationshipTab(
            relationship: ProfileRelationshipCard(
              userId: widget.userId,
              user: user,
              onViewAll: _openCpNest,
            ),
          ),
        ],
      ),
    );
  }

  void _openCpNest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CPNestScreen()),
    );
  }

  Widget _buildBottomActions() {
    if (_isSelf) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FollowRelationshipButton(
              targetUserId: widget.userId,
              onDarkBackground: false,
            ),
            _ActionButton(
              icon: Iconsax.message,
              label: 'Message',
              onTap: () async {
                await HapticFeedback.lightImpact();
                try {
                  final convId = await ChatService.getOrCreateConversation(
                    widget.userId,
                  );
                  if (!mounted) return;

                  final userRes = ref
                      .read(publicUserProfileProvider(widget.userId))
                      .value;
                  context.push(
                    AppRouter.chat,
                    extra: {
                      'conversationId': convId,
                      'targetUserId': widget.userId,
                      'targetUsername': userRes?['username'] ?? 'User',
                      'targetAvatar': userRes?['avatar_url'],
                    },
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error joining chat: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToSocial(int tabIndex) {
    context.push(
      AppRouter.socialDetail,
      extra: {'userId': widget.userId, 'tab': tabIndex},
    );
  }
}

class _GlassAppBarButton extends StatelessWidget {
  const _GlassAppBarButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
