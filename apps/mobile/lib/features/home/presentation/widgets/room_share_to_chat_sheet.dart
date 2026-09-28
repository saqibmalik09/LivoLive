import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/features/home/presentation/widgets/room_invite_helper.dart';

class RoomShareToChatSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;
  final String hostUsername;

  const RoomShareToChatSheet({
    super.key,
    required this.room,
    required this.hostUsername,
  });

  @override
  ConsumerState<RoomShareToChatSheet> createState() =>
      _RoomShareToChatSheetState();
}

class _RoomShareToChatSheetState extends ConsumerState<RoomShareToChatSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchController = TextEditingController();
  String _query = '';

  final Set<String> _selected = {};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendToSelected(List<Map<String, dynamic>> friends) async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);

    final targets = friends
        .where((u) => _selected.contains(u['id']?.toString()))
        .toList();
    int sent = 0;
    final errors = <String>[];

    for (final user in targets) {
      try {
        await _sendInviteWithNotification(user);
        sent++;
      } catch (e) {
        errors.add(user['username'] ?? 'user');
      }
    }

    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errors.isEmpty
              ? 'Invite sent to $sent friend${sent == 1 ? '' : 's'}'
              : 'Sent to $sent, failed: ${errors.join(', ')}',
        ),
        backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _sendToUser(Map<String, dynamic> user) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _sendInviteWithNotification(user);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${user['username'] ?? 'user'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendInviteWithNotification(Map<String, dynamic> user) async {
    final targetId = user['id']?.toString();
    if (targetId == null) return;

    await RoomInviteHelper.sendRoomInvite(
      targetUserId: targetId,
      room: widget.room,
      hostUsername: widget.hostUsername,
    );

    try {
      await Supabase.instance.client.from('system_notifications').insert({
        'user_id': targetId,
        'title': '${widget.hostUsername} invited you!',
        'content': 'Join the live room: ${widget.room['title'] ?? 'Room'}',
        'type': 'room_invite',
        'metadata': {
          'room_id': widget.room['id'].toString(),
          'room_title': widget.room['title'],
          'room_image_url': widget.room['image_url'],
          'host_username': widget.hostUsername,
        },
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight * 0.88 - viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Color(0xFF1A0A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  const Icon(Iconsax.send_2, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Send invite – ${widget.room['title'] ?? 'Room'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Friends'),
                    Tab(text: 'Search'),
                  ],
                ),
              ),
            ),

            Flexible(
              child: TabBarView(
                controller: _tab,
                children: [
                  _FriendsTab(
                    selected: _selected,
                    sending: _sending,
                    onToggle: (id) => setState(() {
                      _selected.contains(id)
                          ? _selected.remove(id)
                          : _selected.add(id);
                    }),
                    onSelectAll: (ids) => setState(() {
                      if (_selected.length == ids.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(ids);
                      }
                    }),
                    onSend: _sendToSelected,
                  ),
                  _SearchTab(
                    searchController: _searchController,
                    query: _query,
                    onQueryChanged: (v) => setState(() => _query = v.trim()),
                    sending: _sending,
                    onSendToUser: _sendToUser,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  final Set<String> selected;
  final bool sending;
  final ValueChanged<String> onToggle;
  final void Function(List<String> allIds) onSelectAll;
  final Future<void> Function(List<Map<String, dynamic>> friends) onSend;

  const _FriendsTab({
    required this.selected,
    required this.sending,
    required this.onToggle,
    required this.onSelectAll,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).value?.session?.user.id ?? '';
    final friendsAsync = ref.watch(followingListProvider(myId));

    return friendsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error loading friends',
          style: TextStyle(color: Colors.red[300]),
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.people, color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'You are not following anyone yet',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Follow people to quickly invite them to rooms',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final allIds = friends.map((u) => u['id']?.toString() ?? '').toList();
        final allSelected = selected.length == allIds.length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => onSelectAll(allIds),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: allSelected
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                              color: allSelected
                                  ? AppColors.accent
                                  : Colors.white30,
                              width: 1.5,
                            ),
                          ),
                          child: allSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (selected.isNotEmpty)
                    Text(
                      '${selected.length} selected',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                itemCount: friends.length,
                separatorBuilder: (context, i) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, i) {
                  final user = friends[i];
                  final uid = user['id']?.toString() ?? '';
                  final isSelected = selected.contains(uid);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: user['avatar_url'] != null
                              ? CachedNetworkImageProvider(user['avatar_url'])
                              : null,
                          backgroundColor: Colors.white12,
                          child: user['avatar_url'] == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 22,
                                )
                              : null,
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      user['username'] ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle:
                        user['bio'] != null &&
                            (user['bio'] as String).isNotEmpty
                        ? Text(
                            user['bio'],
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : Colors.white30,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    onTap: () => onToggle(uid),
                  );
                },
              ),
            ),

            if (selected.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: sending ? null : () => onSend(friends),
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Iconsax.send_1,
                            color: Colors.white,
                            size: 18,
                          ),
                    label: Text(
                      sending ? 'Sending…' : 'Send Invite (${selected.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
          ],
        );
      },
    );
  }
}

class _SearchTab extends ConsumerWidget {
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final bool sending;
  final Future<void> Function(Map<String, dynamic> user) onSendToUser;

  const _SearchTab({
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.sending,
    required this.onSendToUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(userSearchProvider(query));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Username or UID…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Iconsax.search_normal,
                color: Colors.white54,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: searchAsync.when(
              data: (users) {
                if (!isUserSearchQueryReady(query)) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.search_normal_1,
                          color: Colors.white12,
                          size: 40,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Type username or UID',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No user found',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: users.length,
                  separatorBuilder: (context, i) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final shortId = user['short_id']?.toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: user['avatar_url'] != null
                            ? CachedNetworkImageProvider(user['avatar_url'])
                            : null,
                        backgroundColor: Colors.white12,
                        child: user['avatar_url'] == null
                            ? const Icon(Icons.person, color: Colors.white54)
                            : null,
                      ),
                      title: Text(
                        user['username'] ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: shortId != null
                          ? Text(
                              'UID: $shortId',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            )
                          : null,
                      trailing: sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : const Icon(Iconsax.send_1, color: AppColors.accent),
                      onTap: sending ? null : () => onSendToUser(user),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Search error',
                  style: TextStyle(color: Colors.red[300]),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}
