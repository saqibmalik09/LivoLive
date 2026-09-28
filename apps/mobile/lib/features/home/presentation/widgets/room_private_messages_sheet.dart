import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/chat/presentation/pages/chat_screen.dart';

class _ActiveChat {
  const _ActiveChat({
    required this.conversationId,
    required this.targetUserId,
    required this.targetUsername,
    this.targetAvatar,
  });

  final String conversationId;
  final String targetUserId;
  final String targetUsername;
  final String? targetAvatar;
}

class RoomPrivateMessagesSheet extends ConsumerStatefulWidget {
  const RoomPrivateMessagesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoomPrivateMessagesSheet(),
    );
  }

  @override
  ConsumerState<RoomPrivateMessagesSheet> createState() =>
      _RoomPrivateMessagesSheetState();
}

class _RoomPrivateMessagesSheetState
    extends ConsumerState<RoomPrivateMessagesSheet> {
  _ActiveChat? _activeChat;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _openConversation(Map<String, dynamic> room) {
    final otherUser = room['other_user'] as Map<String, dynamic>?;
    if (otherUser == null) return;

    ChatService.markAsRead(room['id'] as String);
    setState(() {
      _activeChat = _ActiveChat(
        conversationId: room['id'] as String,
        targetUserId: otherUser['id'] as String,
        targetUsername: otherUser['username'] as String? ?? 'User',
        targetAvatar: otherUser['avatar_url'] as String?,
      );
    });
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.88,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _backToList() {
    setState(() => _activeChat = null);
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.65,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inChat = _activeChat != null;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: inChat ? 0.88 : 0.65,
      minChildSize: inChat ? 0.55 : 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
          ),
          clipBehavior: Clip.antiAlias,
          child: inChat
              ? ChatScreen(
                  key: ValueKey(_activeChat!.conversationId),
                  conversationId: _activeChat!.conversationId,
                  targetUserId: _activeChat!.targetUserId,
                  targetUsername: _activeChat!.targetUsername,
                  targetAvatar: _activeChat!.targetAvatar,
                  embeddedInSheet: true,
                  onBack: _backToList,
                )
              : _buildFriendList(scrollController),
        );
      },
    );
  }

  Widget _buildFriendList(ScrollController scrollController) {
    final roomsAsync = ref.watch(chatRoomsWithDetailsProvider);
    final mutualFriendsAsync = ref.watch(mutualFriendsProvider);

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
        ),
        Expanded(
          child: roomsAsync.when(
            data: (rooms) {
              final mutualIds = mutualFriendsAsync.value ?? [];
              final friendRooms = rooms.where((room) {
                final otherUser = room['other_user'] as Map<String, dynamic>?;
                if (otherUser == null) return false;
                return mutualIds.contains(otherUser['id']?.toString());
              }).toList();

              if (friendRooms.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.message,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No friend messages yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Messages from mutual friends will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: friendRooms.length,
                itemBuilder: (context, index) {
                  final room = friendRooms[index];
                  return _FriendMessageTile(
                    room: room,
                    onTap: () => _openConversation(room),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.yellowAccent),
            ),
            error: (err, _) => Center(
              child: Text(
                'Could not load messages',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendMessageTile extends StatelessWidget {
  const _FriendMessageTile({required this.room, required this.onTap});

  final Map<String, dynamic> room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final otherUser = room['other_user'] as Map<String, dynamic>?;
    final lastMsg = room['last_message'] as Map<String, dynamic>?;
    final unreadCount = room['unread_count'] as int? ?? 0;
    final lastMsgTime = room['last_message_at'] != null
        ? DateTime.parse(room['last_message_at'] as String)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: unreadCount > 0
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unreadCount > 0
              ? AppColors.gold.withValues(alpha: 0.35)
              : Colors.white10,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryUltraLight,
                      backgroundImage: otherUser?['avatar_url'] != null
                          ? CachedNetworkImageProvider(
                              otherUser!['avatar_url'] as String,
                            )
                          : null,
                      child: otherUser?['avatar_url'] == null
                          ? const Icon(Iconsax.user, color: AppColors.primary)
                          : null,
                    ),
                    if (otherUser?['is_online'] == true)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherUser?['username'] as String? ?? 'User',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMsgTime != null)
                            Text(
                              _formatTime(lastMsgTime),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _messagePreview(lastMsg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: unreadCount > 0 ? 0.85 : 0.5,
                          ),
                          fontSize: 13,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day &&
        now.month == date.month &&
        now.year == date.year) {
      return DateFormat('hh:mm a').format(date);
    }
    return DateFormat('dd/MM').format(date);
  }

  String _messagePreview(Map<String, dynamic>? msg) {
    if (msg == null) return 'No messages yet';
    final type = msg['message_type'];
    if (type == 'image') return '📷 Image';
    if (type == 'voice') return '🎤 Voice message';
    if (type == 'gift') return '🎁 Sent a gift';
    final meta = msg['metadata'] as Map<String, dynamic>?;
    if (meta?['is_room_invite'] == true) return '🎙️ Room invite';
    return msg['content'] as String? ?? '...';
  }
}

int friendMessagesUnreadCount(WidgetRef ref) {
  final rooms = ref.watch(chatRoomsWithDetailsProvider).valueOrNull ?? [];
  final mutualIds = ref.watch(mutualFriendsProvider).valueOrNull ?? [];
  var total = 0;
  for (final room in rooms) {
    final otherUser = room['other_user'] as Map<String, dynamic>?;
    if (otherUser == null) continue;
    if (!mutualIds.contains(otherUser['id']?.toString())) continue;
    total += room['unread_count'] as int? ?? 0;
  }
  return total;
}
