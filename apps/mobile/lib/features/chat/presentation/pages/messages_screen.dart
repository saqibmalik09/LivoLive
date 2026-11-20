import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/live_in_room_badge.dart';
import 'package:sk_live/features/chat/presentation/widgets/message_category_icons.dart';
import 'package:sk_live/features/chat/presentation/widgets/message_flow_background.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_background.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_tab_bar.dart';
import 'package:sk_live/features/home/presentation/widgets/party_ref_widgets.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  int _contactsSubTab = 1;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  double _s(BuildContext context) => MediaQuery.sizeOf(context).width / 750;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: MessageFlowBackground.fallbackColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leadingWidth: _isSearching ? 48 : 0,
        leading: _isSearching
            ? IconButton(
                onPressed: () => setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                }),
                icon: const Icon(
                  Iconsax.arrow_left,
                  color: AppColors.textPrimary,
                ),
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.messages_searchFriendsHint,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: AppColors.textHint),
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (!mounted) return;
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  );
                },
              )
            : HomeRefTabBar(
                controller: _tabController,
                labels: [
                  context.l10n.messages_tabMessage,
                  context.l10n.messages_tabContacts,
                ],
              ),
        centerTitle: false,
        actions: [
          if (!_isSearching && _tabController.index == 0)
            IconButton(
              onPressed: () => setState(() => _isSearching = true),
              icon: HomeRefTabBar.rowIcon(
                context,
                Image.asset(
                  'assets/design/home/top_search_gold.webp',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          SizedBox(width: math.max(0, 68 * _s(context) - 24)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HomeRefBackground(
            tabKey: 'message',
            headerBottom: 150,
            fadeEnd: 210,
            dragonFadeFrom: 140,
          ),
          Column(
            children: [
              SizedBox(height: topInset),
              Expanded(
                child: _isSearching && _searchQuery.isNotEmpty
                    ? _buildGlobalSearchResults()
                    : TabBarView(
                        controller: _tabController,
                        children: [_buildMessageTab(), _buildContactsTab()],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTab() {
    final roomsAsync = ref.watch(chatRoomsWithDetailsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MessageCategoryIcons(),
        Expanded(
          child: roomsAsync.when(
            data: (rooms) {
              final filtered = rooms.where((room) {
                final otherUser = room['other_user'] as Map<String, dynamic>?;
                if (otherUser == null) return false;
                if (_searchQuery.isEmpty) return true;
                final username = (otherUser['username'] ?? '')
                    .toString()
                    .toLowerCase();
                return username.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.message_2,
                        size: 80,
                        color: AppColors.textHint.withValues(alpha: 0.35),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.messages_noMessagesYet,
                        style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return _buildConversationList(filtered);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => asyncErrorWidget(err),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsTab() {
    final userId =
        ref.watch(authStateProvider).value?.session?.user.id ??
        Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return Center(child: Text(context.l10n.messages_pleaseSignIn));
    }

    final mutualIdsAsync = ref.watch(mutualFriendsProvider);
    final followingAsync = ref.watch(followingListProvider(userId));
    final followersAsync = ref.watch(followersListProvider(userId));

    final friendCount = mutualIdsAsync.valueOrNull?.length ?? 0;
    final followingCount = followingAsync.valueOrNull?.length ?? 0;
    final fansCount = followersAsync.valueOrNull?.length ?? 0;

    return Column(
      children: [
        _ContactsSubTabBar(
          selectedIndex: _contactsSubTab,
          friendCount: friendCount,
          followingCount: followingCount,
          fansCount: fansCount,
          onSelected: (index) => setState(() => _contactsSubTab = index),
        ),
        Expanded(
          child: _buildContactsList(
            userId: userId,
            mutualIds: mutualIdsAsync.valueOrNull ?? [],
            followingAsync: followingAsync,
            followersAsync: followersAsync,
          ),
        ),
      ],
    );
  }

  Widget _buildContactsList({
    required String userId,
    required List<String> mutualIds,
    required AsyncValue<List<Map<String, dynamic>>> followingAsync,
    required AsyncValue<List<Map<String, dynamic>>> followersAsync,
  }) {
    switch (_contactsSubTab) {
      case 0:
        return followingAsync.when(
          data: (following) {
            final friends = following
                .where((u) => mutualIds.contains(u['id']?.toString()))
                .toList();
            return _buildUserList(friends);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => asyncErrorWidget(err),
        );
      case 1:
        return followingAsync.when(
          data: (users) => _buildUserList(users),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => asyncErrorWidget(err),
        );
      case 2:
        return followersAsync.when(
          data: (users) => _buildUserList(users),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => asyncErrorWidget(err),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.user,
              size: 80,
              color: AppColors.textHint.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.messages_noContent,
              style: TextStyle(
                color: AppColors.textHint.withValues(alpha: 0.7),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        top: 36 * _s(context),
        bottom: homeTabScrollBottomPadding(context),
      ),
      itemCount: users.length,
      itemBuilder: (context, index) => _refUserRow(users[index]),
    );
  }

  Widget _refUserRow(Map<String, dynamic> user) {
    final s = _s(context);
    final avatarUrl = user['avatar_url'];
    return InkWell(
      onTap: () => _openChatWithUser(user),
      child: Padding(
        padding: EdgeInsets.only(left: 28 * s, right: 28 * s, bottom: 39 * s),
        child: SizedBox(
          height: 104 * s,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 104 * s,
                  child: avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          placeholder: (_, _) => const ColoredBox(
                            color: AppColors.primaryUltraLight,
                          ),
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.primaryUltraLight,
                            child: Icon(Iconsax.user, color: AppColors.accent),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.primaryUltraLight,
                          child: Icon(Iconsax.user, color: AppColors.accent),
                        ),
                ),
              ),
              SizedBox(width: 15 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.5 * s),
                    Text(
                      user['username'] ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28 * s,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 1 * s),
                    Text(
                      'Level ${user['user_level'] ?? 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF6B6B6B),
                        fontSize: 26 * s,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12 * s),
              Padding(
                padding: EdgeInsets.only(top: 28 * s),
                child: GestureDetector(
                  onTap: () => _openChatWithUser(user),
                  child: Image.asset(
                    'assets/design/message/btn_chat_pill.webp',
                    width: 97 * s,
                    height: 49 * s,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openChatWithUser(Map<String, dynamic> user) async {
    try {
      final conversationId = await ChatService.getOrCreateConversation(
        user['id'],
      );
      if (mounted) {
        context.push(
          AppRouter.chat,
          extra: {
            'conversationId': conversationId,
            'targetUsername': user['username'],
            'targetAvatar': user['avatar_url'],
            'targetUserId': user['id'],
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildGlobalSearchResults() {
    final searchAsync = ref.watch(userSearchProvider(_searchQuery));

    return searchAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.user_search, size: 64, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text(
                  context.l10n.messages_noUsersFound(_searchQuery),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: 41 * _s(context),
            bottom: homeTabScrollBottomPadding(context),
          ),
          itemCount: users.length,
          itemBuilder: (context, index) => _refUserRow(users[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildConversationList(List<Map<String, dynamic>> rooms) {
    return ListView.builder(
      padding: EdgeInsets.only(bottom: homeTabScrollBottomPadding(context)),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final otherUser = room['other_user'] as Map<String, dynamic>?;
        final activeRoom = otherUser?['active_room'] as Map<String, dynamic>?;
        final lastMsg = room['last_message'] as Map<String, dynamic>?;
        final unreadCount = room['unread_count'] as int? ?? 0;

        final lastMsgTime = room['last_message_at'] != null
            ? DateTime.parse(room['last_message_at'])
            : null;

        final s = _s(context);
        final avatarUrl = otherUser?['avatar_url'];
        final unreadPill = Container(
          constraints: BoxConstraints(minWidth: 36 * s, minHeight: 26 * s),
          padding: EdgeInsets.symmetric(horizontal: 7 * s),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF4797B),
            borderRadius: BorderRadius.circular(13 * s),
          ),
          child: Text(
            unreadCount > 99 ? '99+' : unreadCount.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 20 * s,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (otherUser != null) {
                ChatService.markAsRead(room['id']);
                context.push(
                  AppRouter.chat,
                  extra: {
                    'conversationId': room['id'],
                    'targetUsername': otherUser['username'],
                    'targetAvatar': otherUser['avatar_url'],
                    'targetUserId': otherUser['id'],
                  },
                );
              }
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: 31 * s,
                right: 29 * s,
                bottom: 43 * s,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 100 * s,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AvatarWithLiveRoomBadge(
                          activeRoom: activeRoom,
                          avatar: ClipOval(
                            child: SizedBox.square(
                              dimension: 100 * s,
                              child: avatarUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 200,
                                      placeholder: (_, _) => const ColoredBox(
                                        color: AppColors.primaryUltraLight,
                                      ),
                                      errorWidget: (_, _, _) =>
                                          const ColoredBox(
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
                        if (otherUser?['is_online'] == true &&
                            activeRoom == null)
                          Positioned(
                            right: 4 * s,
                            bottom: 4 * s,
                            child: Container(
                              width: 22 * s,
                              height: 22 * s,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3 * s,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        if (unreadCount > 0)
                          Positioned(
                            left: 61 * s,
                            top: activeRoom == null ? 3 * s : 71 * s,
                            child: unreadPill,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 17 * s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20 * s),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                otherUser?['username'] ?? 'User',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 26 * s,
                                  color: const Color(0xFF1A1A1A),
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (lastMsgTime != null) ...[
                              SizedBox(width: 12 * s),
                              Text(
                                _formatTime(lastMsgTime),
                                style: TextStyle(
                                  color: const Color(0xFF6B6B6B),
                                  fontSize: 21 * s,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (activeRoom != null)
                          GestureDetector(
                            onTap: () {
                              openRoomLive(
                                context,
                                Map<String, dynamic>.from(activeRoom),
                              );
                            },
                            child: Text(
                              context.l10n.messages_inRoom(
                                activeRoom['title'] ?? 'Room',
                              ),
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 21 * s,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(
                          _getMessagePreview(lastMsg),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF6B6B6B),
                            fontSize: 25 * s,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day &&
        now.month == date.month &&
        now.year == date.year) {
      return DateFormat('hh:mm a').format(date);
    }
    return DateFormat('dd/MM/yy').format(date);
  }

  String _getMessagePreview(Map<String, dynamic>? msg) {
    if (msg == null) return context.l10n.messages_noMessagesYet;
    final type = msg['message_type'];
    if (type == 'image') return '📷 Image';
    if (type == 'voice') return '🎤 Voice message';
    if (type == 'gift') return '🎁 Sent a gift';
    final meta = msg['metadata'] as Map<String, dynamic>?;
    if (meta?['is_room_invite'] == true) {
      return '🎙️ Room invite — tap to join';
    }
    return msg['content'] ?? '...';
  }
}

class _ContactsSubTabBar extends StatelessWidget {
  const _ContactsSubTabBar({
    required this.selectedIndex,
    required this.friendCount,
    required this.followingCount,
    required this.fansCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int friendCount;
  final int followingCount;
  final int fansCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.messages_friendCount(friendCount),
      context.l10n.messages_followingCount(followingCount),
      context.l10n.messages_fansCount(fansCount),
    ];

    final s = MediaQuery.sizeOf(context).width / 750;
    return Padding(
      padding: EdgeInsets.only(top: 41 * s),
      child: PartyRefFilterChips<int>(
        values: const [0, 1, 2],
        selected: selectedIndex,
        labelOf: (i) => labels[i],
        onSelect: onSelected,
      ),
    );
  }
}
