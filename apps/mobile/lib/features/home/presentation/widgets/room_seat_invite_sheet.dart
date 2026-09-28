import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/providers/room_invitation_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/user_search_query.dart';

class RoomSeatInviteSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;
  final int? seatIndex;

  const RoomSeatInviteSheet({super.key, required this.room, this.seatIndex});

  @override
  ConsumerState<RoomSeatInviteSheet> createState() =>
      _RoomSeatInviteSheetState();
}

class _RoomSeatInviteSheetState extends ConsumerState<RoomSeatInviteSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _sending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await RoomInvitationActions.sendSeatInvitation(
        roomId: widget.room['id'].toString(),
        inviteeId: user['id'].toString(),
        seatIndex: widget.seatIndex,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seat invite sent to ${user['username'] ?? 'user'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomTitle = widget.room['title'] ?? 'Room';
    final seatLabel = widget.seatIndex != null
        ? 'Seat ${widget.seatIndex! + 1}'
        : 'next available seat';
    final searchAsync = ref.watch(userSearchProvider(_query));
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.88 - viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A0A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Invite on Seat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '"$roomTitle" — $seatLabel — search username or UID',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
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
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: searchAsync.when(
                data: (users) {
                  if (!isUserSearchQueryReady(_query)) {
                    return const Center(
                      child: Text(
                        'Type username or UID',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
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
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar_url'] != null
                              ? CachedNetworkImageProvider(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          user['username'] ?? 'User',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'ID: ${user['short_id'] ?? user['id'].toString().substring(0, 8)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        trailing: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: () => _inviteUser(user),
                                child: const Text(
                                  'Invite',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Search failed: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
