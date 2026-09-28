import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/chat_provider.dart';
import 'package:sk_live/features/chat/presentation/pages/chat_screen.dart';
import 'package:sk_live/features/home/presentation/pages/room_kick_records_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final blockedChatConversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('conversations')
          .select(
            'id, status, blocked_by, participant_1_id, participant_2_id, '
            'last_message_at, created_at, '
            'p1:participant_1_id(id, username, avatar_url), '
            'p2:participant_2_id(id, username, avatar_url)',
          )
          .eq('status', 'blocked')
          .or('participant_1_id.eq.$userId,participant_2_id.eq.$userId')
          .order('last_message_at', ascending: false);

      final list = <Map<String, dynamic>>[];
      for (final raw in List<Map<String, dynamic>>.from(rows as List)) {
        final blockedBy = raw['blocked_by']?.toString();
        if (blockedBy != null && blockedBy.isNotEmpty && blockedBy != userId) {
          continue;
        }
        final p1 = raw['p1'];
        final p2 = raw['p2'];
        final p1Id = raw['participant_1_id']?.toString();
        final other = p1Id == userId ? p2 : p1;
        list.add({
          ...raw,
          'other_user': other is Map ? Map<String, dynamic>.from(other) : null,
        });
      }
      return list;
    });

class BlacklistScreen extends ConsumerStatefulWidget {
  const BlacklistScreen({super.key, this.hostedRoomId});

  final String? hostedRoomId;

  static Future<void> open(BuildContext context, {String? hostedRoomId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlacklistScreen(hostedRoomId: hostedRoomId),
      ),
    );
  }

  @override
  ConsumerState<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends ConsumerState<BlacklistScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _unblockChat(String conversationId) async {
    try {
      await ChatService.unblockConversation(conversationId);
      ref.invalidate(blockedChatConversationsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.blacklist_unblocked)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roomId = widget.hostedRoomId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0.5,
        title: Text(
          l10n.profile_blacklist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF1A1A2E),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF6BBA),
          tabs: [
            Tab(text: l10n.blacklist_chatTab),
            Tab(text: l10n.blacklist_roomTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ChatBlockedTab(onUnblock: _unblockChat),
          roomId == null || roomId.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.blacklist_noRoom,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : RoomKickRecordsScreen(roomId: roomId, embedded: true),
        ],
      ),
    );
  }
}

class _ChatBlockedTab extends ConsumerWidget {
  const _ChatBlockedTab({required this.onUnblock});

  final Future<void> Function(String conversationId) onUnblock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedChatConversationsProvider);
    final l10n = context.l10n;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.slash, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  l10n.blacklist_emptyChat,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(blockedChatConversationsProvider);
            await ref.read(blockedChatConversationsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              final other = row['other_user'] as Map<String, dynamic>?;
              final name = other?['username']?.toString() ?? l10n.common_user;
              final avatar = other?['avatar_url']?.toString();
              final otherId = other?['id']?.toString() ?? '';
              final convId = row['id']?.toString() ?? '';
              final updated = row['last_message_at'] ?? row['created_at'];
              String? when;
              if (updated != null) {
                final dt = DateTime.tryParse(updated.toString())?.toLocal();
                if (dt != null) {
                  when = DateFormat('yyyy-MM-dd HH:mm').format(dt);
                }
              }

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: avatar != null && avatar.isNotEmpty
                        ? CachedNetworkImageProvider(avatar)
                        : null,
                    child: avatar == null || avatar.isEmpty
                        ? const Icon(Iconsax.user, color: Colors.grey)
                        : null,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    when ?? l10n.chat_conversationBlocked,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: TextButton(
                    onPressed: convId.isEmpty ? null : () => onUnblock(convId),
                    child: Text(l10n.blacklist_unblock),
                  ),
                  onTap: () {
                    if (convId.isEmpty || otherId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: convId,
                          targetUserId: otherId,
                          targetUsername: name,
                          targetAvatar: avatar,
                        ),
                      ),
                    ).then((_) {
                      ref.invalidate(blockedChatConversationsProvider);
                    });
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
