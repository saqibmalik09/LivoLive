import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/features/home/presentation/pages/room_members_screen.dart';
import 'package:sk_live/core/util/room_public_id.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class RoomDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;

  const RoomDetailsSheet({super.key, required this.room});

  @override
  ConsumerState<RoomDetailsSheet> createState() => _RoomDetailsSheetState();
}

class _RoomDetailsSheetState extends ConsumerState<RoomDetailsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _hostData;
  Map<String, dynamic>? _roomStats;
  List<Map<String, dynamic>> _levelConfigs = [];
  bool _isLoadingHost = true;
  bool _isLoadingStats = true;
  bool _isFollowing = false;
  bool _isLoadingFollow = true;
  late Future<List<Map<String, dynamic>>> _adminsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchHostDetails();
    _fetchRoomStats();
    _checkFollowStatus();
    _initAdminsFuture();
  }

  Future<void> _fetchRoomStats() async {
    try {
      final supabase = Supabase.instance.client;

      final statsRes = await supabase
          .from('room_stats')
          .select()
          .eq('room_id', widget.room['id'])
          .maybeSingle();

      final configRes = await supabase
          .from('room_level_configs')
          .select()
          .order('level', ascending: true);

      if (mounted) {
        setState(() {
          _roomStats = statsRes;
          _levelConfigs = List<Map<String, dynamic>>.from(configRes);
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching room stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _initAdminsFuture() {
    _adminsFuture = Supabase.instance.client
        .from('room_members')
        .select('*, user:user_id(*)')
        .eq('room_id', widget.room['id'])
        .eq('role', 'admin');
  }

  Future<void> _removeSubAdmin(String? userId, String username) async {
    if (userId == null || userId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.room_removeAdminTitle),
        content: Text(context.l10n.room_removeAdminBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final res = await Supabase.instance.client.rpc(
        'remove_room_sub_admin',
        params: {'p_room_id': widget.room['id'], 'p_user_id': userId},
      );
      final map = res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
      if (map['success'] != true) {
        throw Exception(map['message']?.toString() ?? 'Remove failed');
      }
      if (!mounted) return;
      setState(_initAdminsFuture);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.room_removedAsAdmin(username))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _fetchHostDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.room['host_id'])
          .single();
      if (mounted) {
        setState(() {
          _hostData = response;
          _isLoadingHost = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHost = false);
    }
  }

  Future<void> _checkFollowStatus() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('room_members')
          .select()
          .eq('room_id', widget.room['id'])
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFollowing = response != null;
          _isLoadingFollow = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  Future<void> _toggleFollow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingFollow = true);

    try {
      if (_isFollowing) {
        final currentMember = await Supabase.instance.client
            .from('room_members')
            .select('role')
            .eq('room_id', widget.room['id'])
            .eq('user_id', userId)
            .maybeSingle();

        if (currentMember != null && currentMember['role'] == 'member') {
          await Supabase.instance.client
              .from('room_members')
              .delete()
              .eq('room_id', widget.room['id'])
              .eq('user_id', userId);
        } else {
          debugPrint('User is admin/host, not deleting member record');
        }
      } else {
        await Supabase.instance.client.from('room_members').upsert({
          'room_id': widget.room['id'],
          'user_id': userId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        });
      }

      await _checkFollowStatus();
    } catch (e) {
      debugPrint('FOLLOW_ERROR: $e');
      if (mounted) {
        setState(() => _isLoadingFollow = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildTabs(),
                  const SizedBox(height: 20),
                  _buildContent(),
                ],
              ),
            ),
          ),

          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.black12, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: widget.room['image_url'] != null
                  ? CachedNetworkImage(
                      imageUrl: widget.room['image_url'],
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.meeting_room,
                      color: Colors.black26,
                      size: 40,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('??', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.room['title'] ?? 'Room Name',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('??', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('??', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.indigo],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '25',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Room:${roomPublicId(widget.room)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.brown.withValues(alpha: 0.3),
              border: Border.all(color: Colors.brown, width: 1),
            ),
            child: const Icon(
              Icons.home_work_outlined,
              color: Colors.orange,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFE6D08D), Color(0xFFC7A75C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC7A75C).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Room Info'),
          Tab(text: 'Admin'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return [_buildRoomInfoTab(), _buildAdminTab()][_tabController.index];
  }

  Widget _buildAdminTab() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isCurrentUserHost = widget.room['host_id'] == currentUserId;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final subAdmins = snapshot.data ?? [];
        final bool isCurrentUserRoomAdmin = subAdmins.any(
          (m) => m['user_id'] == currentUserId,
        );
        final bool canManageAdmins =
            isCurrentUserHost || isCurrentUserRoomAdmin;

        final List<Map<String, dynamic>> allAdmins = [];

        if (_hostData != null) {
          allAdmins.add({'role': 'host', 'user': _hostData});
        }

        allAdmins.addAll(subAdmins);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Admins (${allAdmins.length})',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (canManageAdmins)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RoomMembersScreen(roomId: widget.room['id']),
                          ),
                        );
                      },
                      child: const Text(
                        'Manage',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allAdmins.length,
                itemBuilder: (context, index) {
                  final admin = allAdmins[index];
                  final user = admin['user'];
                  final String role = admin['role'] ?? 'admin';
                  if (user == null) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
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
                                user['username'] ?? 'User',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${user['short_id'] ?? user['id'].toString().substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildBadge(
                          role == 'host' ? 'Host' : 'Admin',
                          role == 'host' ? Colors.orange : Colors.blue,
                          isText: true,
                        ),
                        if (isCurrentUserHost && role == 'admin') ...[
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => _removeSubAdmin(
                              admin['user_id']?.toString() ??
                                  user['id']?.toString(),
                              user['username']?.toString() ?? 'Admin',
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoomInfoTab() {
    int currentLevel = _roomStats?['current_level'] ?? 1;
    int totalExp = (_roomStats?['total_exp'] ?? 0).toInt();

    Map<String, dynamic>? currentConfig;
    Map<String, dynamic>? nextConfig;

    for (var i = 0; i < _levelConfigs.length; i++) {
      if (_levelConfigs[i]['level'] == currentLevel) {
        currentConfig = _levelConfigs[i];
        if (i + 1 < _levelConfigs.length) {
          nextConfig = _levelConfigs[i + 1];
        }
        break;
      }
    }

    double progress = 0.0;
    int expLeft = 0;
    String nextLevelStr = 'Lv.${currentLevel + 1}';

    if (nextConfig != null) {
      int minExp = (currentConfig?['min_exp'] ?? 0).toInt();
      int nextMinExp = (nextConfig['min_exp'] ?? 0).toInt();
      int expInCurrentLevel = totalExp - minExp;
      int expNeededForLevel = nextMinExp - minExp;

      progress = (expInCurrentLevel / expNeededForLevel).clamp(0.0, 1.0);
      expLeft = nextMinExp - totalExp;
      nextLevelStr = 'Lv.${nextConfig['level']}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.room_levelLabel,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingStats)
            const LinearProgressIndicator()
          else ...[
            Row(
              children: [
                Text(
                  'Lv.$currentLevel',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.orange[400]!,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  nextLevelStr,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                expLeft > 0
                    ? '$expLeft Exp lefts to the next level'
                    : 'Max Level Reached',
                style: const TextStyle(color: Colors.redAccent, fontSize: 10),
              ),
            ),
          ],

          const SizedBox(height: 24),

          if (_isLoadingHost)
            const Center(child: CircularProgressIndicator())
          else if (_hostData != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: _hostData!['avatar_url'] != null
                        ? CachedNetworkImageProvider(_hostData!['avatar_url'])
                        : null,
                    child: _hostData!['avatar_url'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _hostData!['username'] ?? 'Host',
                              style: const TextStyle(
                                color: Colors.pinkAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 12,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildBadge('24', Colors.blue),
                            _buildBadge('18', Colors.purple),
                            _buildBadge('20', Colors.red),
                            _buildBadge('SVIP3', Colors.indigo),
                            _buildBadge('Owner', Colors.orange, isText: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Text(
            context.l10n.room_announcement,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.room['announcement'] ??
                'MOST WEEL.COME ??\n?? ADLV FOR HOST ?? ? ?? ? ??',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, {bool isText = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final bool isHost = widget.room['host_id'] == currentUserId;

    if (isHost) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: GestureDetector(
        onTap: _isLoadingFollow ? null : _toggleFollow,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: _isFollowing
                ? LinearGradient(colors: [Colors.grey[300]!, Colors.grey[400]!])
                : const LinearGradient(
                    colors: [Color(0xFFE6D08D), Color(0xFFC7A75C)],
                  ),
            border: _isFollowing ? Border.all(color: Colors.black12) : null,
          ),
          child: Center(
            child: _isLoadingFollow
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isFollowing ? Icons.check : Icons.favorite,
                        color: _isFollowing ? Colors.black54 : Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: _isFollowing ? Colors.black54 : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
