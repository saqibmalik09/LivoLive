import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyAdminScreen extends ConsumerStatefulWidget {
  const AgencyAdminScreen({
    super.key,
    required this.agencyId,
    required this.ownerId,
    required this.canChangeRoles,
  });

  final String agencyId;
  final String ownerId;
  final bool canChangeRoles;

  @override
  ConsumerState<AgencyAdminScreen> createState() => _AgencyAdminScreenState();
}

class _AgencyAdminScreenState extends ConsumerState<AgencyAdminScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  Map<String, dynamic>? _president;

  @override
  void initState() {
    super.initState();
    _loadPresident();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresident() async {
    if (widget.ownerId.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('id, username, avatar_url, short_id')
          .eq('id', widget.ownerId)
          .maybeSingle();
      if (mounted) setState(() => _president = row);
    } catch (_) {}
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await StaffActions.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = rows
            .where((u) => u['id']?.toString() != widget.ownerId)
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _setRole({
    required String userId,
    required String username,
    required String role,
  }) async {
    final makingAdmin = role == 'admin';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          makingAdmin ? context.l10n.agency_makeAdmin : 'Remove Admin?',
        ),
        content: Text(
          makingAdmin
              ? 'Give $username Agency Admin access? They will see Agency Center.'
              : 'Remove admin access from $username? They will stay as a host.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: makingAdmin
                  ? const Color(0xFF2F80ED)
                  : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(
              makingAdmin ? context.l10n.agency_makeAdmin : 'Remove Admin',
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await ref
        .read(agencyCenterActionsProvider)
        .setMemberRole(agencyId: widget.agencyId, userId: userId, role: role);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['success'] == true
              ? (makingAdmin
                    ? '$username is now an Agency Admin'
                    : 'Admin removed from $username')
              : (res['message']?.toString() ?? context.l10n.common_failed),
        ),
      ),
    );
    if (res['success'] == true) {
      setState(() {
        _results = [];
        _searchCtrl.clear();
      });
    }
  }

  Future<void> _removeFromAgency({
    required String userId,
    required String username,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.agency_removeFromAgency),
        content: Text('Remove $username from the agency completely?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(agencyCenterActionsProvider)
          .removeHost(agencyId: widget.agencyId, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$username removed from agency')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(agencyMembersProvider(widget.agencyId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Agency Admin',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
        data: (members) {
          final admins = members.where((m) {
            final uid = (m['users'] as Map?)?['id']?.toString();
            final role = m['role']?.toString() ?? 'host';
            return role == 'admin' && uid != widget.ownerId;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'President is the agency owner (cannot be removed). You can appoint any user as Admin by ID or username.',
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
              if (!widget.canChangeRoles)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Only the President can add or remove admins.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'President',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _presidentCard(),
              const SizedBox(height: 20),
              if (widget.canChangeRoles) ...[
                const Text(
                  'Add Admin',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search by ID or username',
                    filled: true,
                    fillColor: const Color(0xFFF7F7F9),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._results.map((u) {
                    final uid = u['id']?.toString() ?? '';
                    final name = u['username']?.toString() ?? 'User';
                    final alreadyAdmin = admins.any(
                      (m) => (m['users'] as Map?)?['id']?.toString() == uid,
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: u['avatar_url'] != null
                                ? CachedNetworkImageProvider(
                                    u['avatar_url'].toString(),
                                  )
                                : null,
                            child: u['avatar_url'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'ID ${u['short_id'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: alreadyAdmin || uid.isEmpty
                                ? null
                                : () => _setRole(
                                    userId: uid,
                                    username: name,
                                    role: 'admin',
                                  ),
                            child: Text(
                              alreadyAdmin
                                  ? 'Admin'
                                  : context.l10n.agency_makeAdmin,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 16),
              ],
              const Text(
                'Admins',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (admins.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No admins yet. Search any user above to appoint.',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                )
              else
                ...admins.map((m) => _adminCard(m)),
            ],
          );
        },
      ),
    );
  }

  Widget _presidentCard() {
    final name = _president?['username']?.toString() ?? 'President';
    final avatar = _president?['avatar_url']?.toString();
    final shortId = _president?['short_id']?.toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: avatar != null
                ? CachedNetworkImageProvider(avatar)
                : null,
            child: avatar == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  shortId != null ? 'President · ID $shortId' : 'President',
                  style: const TextStyle(
                    color: Color(0xFFB7791F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0A3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'President',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A5A00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminCard(Map<String, dynamic> m) {
    final user = m['users'] as Map<String, dynamic>?;
    final uid = user?['id']?.toString() ?? '';
    final name = user?['username']?.toString() ?? 'User';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: user?['avatar_url'] != null
                    ? CachedNetworkImageProvider(user!['avatar_url'].toString())
                    : null,
                child: user?['avatar_url'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Agency Admin${user?['short_id'] != null ? ' · ID ${user!['short_id']}' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF2F80ED),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.canChangeRoles && uid.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _setRole(userId: uid, username: name, role: 'host'),
                    child: const Text('Remove Admin'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _removeFromAgency(userId: uid, username: name),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
