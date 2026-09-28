import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/room_invitation_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

final roomMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      roomId,
    ) async {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('room_members')
          .select('*, user:user_id(username, avatar_url, country_code)')
          .eq('room_id', roomId)
          .order('joined_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    });

final roomHostIdProvider = FutureProvider.family<String?, String>((
  ref,
  roomId,
) async {
  final row = await Supabase.instance.client
      .from('rooms')
      .select('host_id')
      .eq('id', roomId)
      .maybeSingle();
  return row?['host_id'] as String?;
});

class RoomMembersScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomMembersScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomMembersScreen> createState() => _RoomMembersScreenState();
}

class _RoomMembersScreenState extends ConsumerState<RoomMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isGlobalSearch => isUserSearchQueryReady(_searchQuery);

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(roomMembersProvider(widget.roomId));
    final hostIdAsync = ref.watch(roomHostIdProvider(widget.roomId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final hostId = hostIdAsync.valueOrNull;
    final bool isHost = hostId != null && hostId == currentUserId;
    final globalSearchAsync = isHost && _isGlobalSearch
        ? ref.watch(userSearchProvider(_searchQuery.trim()))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isHost
              ? context.l10n.room_membersAndAdmin
              : context.l10n.room_membersList,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: isHost
                          ? 'Search any user by name or ID...'
                          : 'Search members...',
                      prefixIcon: const Icon(
                        Iconsax.search_normal,
                        size: 20,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (isHost) ...[
                  const SizedBox(height: 8),
                  Text(
                    _isGlobalSearch
                        ? 'Showing users from entire app — tap Make Sub-Admin'
                        : 'Type 2+ characters to find anyone and make them admin',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: isHost && _isGlobalSearch
                ? _buildGlobalSearchResults(
                    globalSearchAsync,
                    hostId,
                    membersAsync.valueOrNull ?? [],
                  )
                : membersAsync.when(
                    data: (members) => _buildMemberList(members, hostId),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSearchResults(
    AsyncValue<List<Map<String, dynamic>>>? searchAsync,
    String? hostId,
    List<Map<String, dynamic>> members,
  ) {
    if (searchAsync == null) {
      return const SizedBox.shrink();
    }

    return searchAsync.when(
      data: (users) {
        final adminIds = members
            .where((m) => m['role'] == 'admin' || m['role'] == 'host')
            .map((m) => m['user_id'])
            .toSet();

        final filtered = users.where((u) {
          final id = u['id'] as String?;
          if (id == null) return false;
          if (id == hostId) return false;
          if (id == Supabase.instance.client.auth.currentUser?.id) return false;
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No users found', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final user = filtered[index];
            final userId = user['id'] as String;
            final username = user['username'] as String? ?? 'User';
            final alreadyAdmin = adminIds.contains(userId);

            return Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['avatar_url'] != null
                      ? CachedNetworkImageProvider(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'ID: ${user['short_id'] ?? userId.substring(0, 8)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: alreadyAdmin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRoleBadge('admin'),
                          TextButton(
                            onPressed: () => _removeAdmin(userId, false),
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    : TextButton(
                        onPressed: () =>
                            _assignAdminFromSearch(userId, username),
                        child: Text(
                          context.l10n.room_inviteSubAdmin,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Search failed: $e')),
    );
  }

  Widget _buildMemberList(List<Map<String, dynamic>> members, String? hostId) {
    final filteredMembers = members.where((m) {
      final username = (m['user']?['username'] as String? ?? '').toLowerCase();
      return username.contains(_searchQuery.toLowerCase());
    }).toList();

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isHost = hostId != null && hostId == currentUserId;
    final bool isRoomAdmin = members.any(
      (m) => m['user_id'] == currentUserId && m['role'] == 'admin',
    );
    final bool canManageAdmins = isHost || isRoomAdmin;

    if (filteredMembers.isEmpty) {
      return _buildEmptyState(isHost: isHost);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) {
        final member = filteredMembers[index];
        final user = member['user'];
        final role = member['role'] as String;
        final bool isMe = member['user_id'] == currentUserId;

        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user['avatar_url'] != null
                  ? CachedNetworkImageProvider(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              user['username'] ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              user['country_code'] ?? 'PK',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoleBadge(role),
                if (canManageAdmins && !isMe && role == 'member')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (val) {
                      if (val == 'invite_admin') {
                        _sendAdminInvite(member['user_id'], user['username']);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'invite_admin',
                        child: Text(context.l10n.room_inviteSubAdmin),
                      ),
                    ],
                  ),
                if (role == 'admin' && (isHost || isMe))
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (val) {
                      if (val == 'remove_admin') {
                        _removeAdmin(member['user_id'], isMe);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'remove_admin',
                        child: Text(
                          isMe
                              ? 'Resign as Admin'
                              : context.l10n.room_removeAdmin,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignAdminFromSearch(String userId, String username) async {
    try {
      await RoomInvitationActions.assignAdminBySearch(
        roomId: widget.roomId,
        inviteeId: userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invitation sent to $username. They must accept to become Sub-Admin.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _sendAdminInvite(String userId, String username) async {
    try {
      await RoomInvitationActions.sendAdminInvitation(
        roomId: widget.roomId,
        inviteeId: userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to $username. Waiting for accept.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _removeAdmin(String userId, bool isSelf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isSelf ? 'Resign as Admin?' : context.l10n.room_removeAdminTitle,
        ),
        content: Text(
          isSelf
              ? 'Are you sure you want to resign from your Sub-Admin role?'
              : context.l10n.room_removeAdminBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isSelf ? 'Resign' : 'Remove',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await Supabase.instance.client.rpc(
        'remove_room_sub_admin',
        params: {'p_room_id': widget.roomId, 'p_user_id': userId},
      );
      final map = res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
      if (map['success'] != true) {
        throw Exception(map['message']?.toString() ?? 'Remove failed');
      }

      ref.invalidate(roomMembersProvider(widget.roomId));
      if (_searchQuery.isNotEmpty) {
        _searchController.clear();
        setState(() => _searchQuery = '');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSelf ? 'You have resigned' : 'Admin removed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;

    switch (role) {
      case 'host':
        color = Colors.orange;
        label = 'Host';
        break;
      case 'admin':
        color = Colors.blue;
        label = 'Admin';
        break;
      default:
        color = Colors.grey;
        label = 'Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isHost}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.user_tag, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isHost
                ? 'No members yet — search above to add admin'
                : 'No members found',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
