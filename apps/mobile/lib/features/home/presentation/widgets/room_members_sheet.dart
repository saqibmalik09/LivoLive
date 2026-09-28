import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/inventory_provider.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:sk_live/core/widgets/user_member_identity.dart';
import 'package:sk_live/features/home/presentation/pages/shop_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

typedef RoomMemberTapCallback =
    void Function(
      String userId,
      String username,
      String? avatarUrl,
      int? seatIndex,
    );

class RoomMembersSheet extends ConsumerStatefulWidget {
  const RoomMembersSheet({
    super.key,
    required this.roomId,
    required this.hostId,
    required this.onlineUsers,
    required this.seatIndexForUser,
    required this.onMemberTap,
  });

  final String roomId;
  final String? hostId;
  final List<Map<String, dynamic>> onlineUsers;
  final int? Function(String userId) seatIndexForUser;
  final RoomMemberTapCallback onMemberTap;

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
    required String? hostId,
    required List<Map<String, dynamic>> onlineUsers,
    required int? Function(String userId) seatIndexForUser,
    required RoomMemberTapCallback onMemberTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomMembersSheet(
        roomId: roomId,
        hostId: hostId,
        onlineUsers: onlineUsers,
        seatIndexForUser: seatIndexForUser,
        onMemberTap: onMemberTap,
      ),
    );
  }

  @override
  ConsumerState<RoomMembersSheet> createState() => _RoomMembersSheetState();
}

class _RoomMembersSheetState extends ConsumerState<RoomMembersSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, Map<String, dynamic>> _enrichedUsers = {};
  final Set<String> _adminIds = {};
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMemberData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberData() async {
    final ids = widget.onlineUsers
        .map((u) => u['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    try {
      final supabase = Supabase.instance.client;

      if (ids.isNotEmpty) {
        final usersRes = await supabase
            .from('users')
            .select('id, username, avatar_url, vip_level')
            .inFilter('id', ids);

        for (final row in usersRes as List) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['id']?.toString();
          if (id != null) _enrichedUsers[id] = map;
        }
      }

      final adminsRes = await supabase
          .from('room_members')
          .select('user_id')
          .eq('room_id', widget.roomId)
          .eq('role', 'admin');

      for (final row in adminsRes as List) {
        final id = row['user_id']?.toString();
        if (id != null) _adminIds.add(id);
      }
    } catch (e) {
      debugPrint('RoomMembersSheet load error: $e');
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Map<String, dynamic> _resolveUser(Map<String, dynamic> presenceUser) {
    final id = presenceUser['id']?.toString() ?? '';
    final enriched = _enrichedUsers[id];
    return {
      'id': id,
      'username': enriched?['username'] ?? presenceUser['username'] ?? 'User',
      'avatar_url': enriched?['avatar_url'] ?? presenceUser['avatar_url'],
      'vip_level': (enriched?['vip_level'] as num?)?.toInt() ?? 0,
    };
  }

  List<Map<String, dynamic>> get _allMembers {
    return widget.onlineUsers.map(_resolveUser).toList();
  }

  List<Map<String, dynamic>> get _vipMembers {
    return _allMembers
        .where((u) => ((u['vip_level'] as int?) ?? 0) > 0)
        .toList()
      ..sort(
        (a, b) => (b['vip_level'] as int).compareTo(a['vip_level'] as int),
      );
  }

  String? _roleLabel(String userId) {
    if (widget.hostId != null && userId == widget.hostId) return 'Host';
    if (_adminIds.contains(userId)) return 'Admin';
    return null;
  }

  void _openPurchaseCar() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ShopScreen(initialCategoryName: 'car'),
      ),
    );
  }

  void _handleMemberTap(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    Navigator.pop(context);
    widget.onMemberTap(
      userId,
      user['username']?.toString() ?? 'User',
      user['avatar_url'] as String?,
      widget.seatIndexForUser(userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.65;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: maxH + bottomInset,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            indicatorWeight: 2.5,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: context.l10n.room_membersList),
              const Tab(text: 'VIP Seat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMembersListTab(), _buildVipSeatTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersListTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildVehicleSection(),
        const SizedBox(height: 18),
        _buildSectionLabel('list'),
        const SizedBox(height: 8),
        if (_loadingUsers)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.amber,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_allMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No members in room',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          ..._allMembers.map(_buildMemberRow),
      ],
    );
  }

  Widget _buildVipSeatTab() {
    if (_loadingUsers) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
      );
    }

    if (_vipMembers.isEmpty) {
      return const Center(
        child: Text(
          'No VIP users in this room',
          style: TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _vipMembers.length,
      itemBuilder: (context, index) {
        final user = _vipMembers[index];
        final vipLevel = user['vip_level'] as int? ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _handleMemberTap(user),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    UserFramedAvatar(
                      userId: user['id']?.toString() ?? '',
                      avatarUrl: user['avatar_url'] as String?,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username']?.toString() ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VIP$vipLevel',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          UserMemberBadgesRow(
                            userId: user['id']?.toString() ?? '',
                            maxBadges: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleSection() {
    final currentUserId = ref
        .watch(userProfileProvider)
        .value?['id']
        ?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel('vehicle'),
            const Spacer(),
            GestureDetector(
              onTap: _openPurchaseCar,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Purchase Car',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 130,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: currentUserId == null
              ? _buildVehiclePlaceholder()
              : _buildVehicleContent(currentUserId),
        ),
      ],
    );
  }

  Widget _buildVehicleContent(String userId) {
    final assetsAsync = ref.watch(userAssetsProvider(userId));

    return assetsAsync.when(
      data: (assets) {
        final cars = assets
            .where((a) => a.category.toLowerCase() == 'car')
            .toList();
        if (cars.isEmpty) return _buildVehiclePlaceholder();

        final car = cars.where((a) => a.isEquipped).firstOrNull ?? cars.first;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: car.imageUrl != null && car.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: car.imageUrl!,
                        fit: BoxFit.contain,
                      )
                    : car.svgaUrl != null && car.svgaUrl!.isNotEmpty
                    ? SVGAPlayerMuted(resUrl: car.svgaUrl!)
                    : _buildVehiclePlaceholder(inner: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                car.name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
      ),
      error: (e, _) => _buildVehiclePlaceholder(),
    );
  }

  Widget _buildVehiclePlaceholder({bool inner = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: inner ? 40 : 52,
            color: Colors.white24,
          ),
          if (!inner) ...[
            const SizedBox(height: 8),
            const Text(
              'No car equipped',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    final role = _roleLabel(userId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleMemberTap(user),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserFramedAvatar(
                userId: userId,
                avatarUrl: user['avatar_url'] as String?,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user['username']?.toString() ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (role != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            role == 'Host' ? Icons.star : Iconsax.user,
                            size: 14,
                            color: role == 'Host'
                                ? Colors.orange
                                : Colors.lightBlueAccent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    UserMemberBadgesRow(userId: userId, maxBadges: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, {required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      backgroundImage: url != null && url.isNotEmpty
          ? CachedNetworkImageProvider(url)
          : null,
      child: url == null || url.isEmpty
          ? Icon(Icons.person, color: Colors.white38, size: radius)
          : null,
    );
  }
}
