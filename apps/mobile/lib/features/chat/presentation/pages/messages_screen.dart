import 'dart:async';

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
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textPrimary,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
                tabs: [
                  Tab(text: context.l10n.messages_tabMessage),
                  Tab(text: context.l10n.messages_tabContacts),
                ],
              ),
        centerTitle: false,
        actions: [
          if (!_isSearching && _tabController.index == 0)
            IconButton(
              onPressed: () => setState(() => _isSearching = true),
              icon: const Icon(
                Iconsax.search_normal,
                color: AppColors.accent,
                size: 24,
              ),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MessageFlowBackground(),
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
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        homeTabScrollBottomPadding(context),
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryUltraLight,
              backgroundImage: user['avatar_url'] != null
                  ? CachedNetworkImageProvider(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? const Icon(Iconsax.user, color: AppColors.accent)
                  : null,
            ),
            title: Text(
              user['username'] ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Level ${user['user_level'] ?? 1}'),
            trailing: const Icon(
              Iconsax.message,
              color: AppColors.accent,
              size: 20,
            ),
            onTap: () => _openChatWithUser(user),
          ),
        );
      },
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
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            homeTabScrollBottomPadding(context),
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primaryUltraLight,
                  backgroundImage: user['avatar_url'] != null
                      ? CachedNetworkImageProvider(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? const Icon(Iconsax.user, color: AppColors.accent)
                      : null,
                ),
                title: Text(
                  user['username'] ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Level ${user['user_level'] ?? 1}'),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.message,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                onTap: () => _openChatWithUser(user),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildConversationList(List<Map<String, dynamic>> rooms) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        homeTabScrollBottomPadding(context),
      ),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (unreadCount > 0 ? AppColors.gold : Colors.black)
                    .withValues(alpha: 0.06),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
            border: unreadCount > 0
                ? Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : Border.all(color: Colors.white, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          AvatarWithLiveRoomBadge(
                            activeRoom: activeRoom,
                            avatar: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: unreadCount > 0
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.gold,
                                          Color(0xFFFFE082),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade300,
                                          Colors.grey.shade100,
                                        ],
                                      ),
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: AppColors.primaryUltraLight,
                                  backgroundImage:
                                      otherUser?['avatar_url'] != null
                                      ? CachedNetworkImageProvider(
                                          otherUser!['avatar_url'],
                                        )
                                      : null,
                                  child: otherUser?['avatar_url'] == null
                                      ? const Icon(
                                          Iconsax.user,
                                          color: AppColors.primary,
                                          size: 28,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          if (otherUser?['is_online'] == true &&
                              activeRoom == null)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    otherUser?['username'] ?? 'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: unreadCount > 0
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (lastMsgTime != null)
                                  Text(
                                    _formatTime(lastMsgTime),
                                    style: TextStyle(
                                      color: unreadCount > 0
                                          ? AppColors.gold
                                          : AppColors.textHint,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            if (activeRoom != null) ...[
                              const SizedBox(height: 6),
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
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getMessagePreview(lastMsg),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unreadCount > 0
                                          ? AppColors.textPrimary
                                          : const Color(0xFF888888),
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 28,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
