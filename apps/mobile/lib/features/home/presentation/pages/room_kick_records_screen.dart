import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

final roomKickRecordsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      roomId,
    ) async {
      final supabase = Supabase.instance.client;
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final response = await supabase
          .from('room_kicks')
          .select(
            '*, user:user_id(username, avatar_url), admin:admin_id(username)',
          )
          .eq('room_id', roomId)
          .gte('kicked_at', since)
          .order('kicked_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    });

class RoomKickRecordsScreen extends ConsumerStatefulWidget {
  final String roomId;
  final bool embedded;
  const RoomKickRecordsScreen({
    super.key,
    required this.roomId,
    this.embedded = false,
  });

  @override
  ConsumerState<RoomKickRecordsScreen> createState() =>
      _RoomKickRecordsScreenState();
}

class _RoomKickRecordsScreenState extends ConsumerState<RoomKickRecordsScreen> {
  bool _isRemoving = false;

  Future<void> _unblockUser(String kickId) async {
    setState(() => _isRemoving = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('room_kicks').delete().eq('id', kickId);
      ref.invalidate(roomKickRecordsProvider(widget.roomId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User unblocked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(roomKickRecordsProvider(widget.roomId));

    final body = recordsAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final user = record['user'];
            final admin = record['admin'];
            final kickedAt = DateTime.parse(record['kicked_at']).toLocal();
            final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(kickedAt);

            return Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: user['avatar_url'] != null
                          ? CachedNetworkImageProvider(user['avatar_url'])
                          : null,
                      child: user['avatar_url'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? 'Unknown User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By: ${admin['username'] ?? 'Admin'} • $timeStr',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _kickDurationLabel(record['expires_at']),
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (record['reason'] != null &&
                              record['reason'].toString().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${record['reason']}',
                              style: TextStyle(
                                color: Colors.red[300],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _isRemoving
                          ? null
                          : () => _showUnblockConfirm(record['id']),
                      child: Text(
                        context.l10n.blacklist_unblock,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFFF5F6F8), child: body);
    }

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
          context.l10n.room_kickRecordsTitle,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: body,
    );
  }

  String _kickDurationLabel(dynamic expiresAtRaw) {
    if (expiresAtRaw == null || expiresAtRaw.toString().isEmpty) {
      return 'Duration: ${context.l10n.room_kickDurationPermanent}';
    }
    try {
      final expires = DateTime.parse(expiresAtRaw.toString()).toLocal();
      final stamp = DateFormat('yyyy-MM-dd HH:mm').format(expires);
      if (expires.isBefore(DateTime.now())) {
        return 'Expired · until $stamp';
      }
      return 'Until $stamp';
    } catch (_) {
      return 'Duration: —';
    }
  }

  void _showUnblockConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.room_unblockUser),
        content: const Text(
          'This removes the blacklist/kick so they can join the room again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _unblockUser(id);
            },
            child: const Text(
              'Unblock',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.user_minus, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No kick records in the last 7 days',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
