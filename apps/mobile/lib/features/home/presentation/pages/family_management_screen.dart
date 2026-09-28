import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/family_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class FamilyManagementScreen extends ConsumerStatefulWidget {
  final String familyId;
  const FamilyManagementScreen({super.key, required this.familyId});

  @override
  ConsumerState<FamilyManagementScreen> createState() =>
      _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends ConsumerState<FamilyManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Family Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7B61FF),
          labelColor: const Color(0xFF7B61FF),
          unselectedLabelColor: Colors.black38,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Members'),
            Tab(text: 'Level Rules'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3E5F5), Colors.white],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [_buildRequestsTab(), _buildMembersTab(), _buildRulesTab()],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    final requestsAsync = ref.watch(
      familyJoinRequestsProvider(widget.familyId),
    );

    return requestsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
      ),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: Colors.red)),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'No pending requests',
              style: TextStyle(color: Colors.black38),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final userData = request['users'] as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildAvatar(
                    userData['avatar_url'],
                    50,
                    vipLevel: (userData['vip_level'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['username'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Requested: ${_formatDate(request['created_at'])}',
                          style: const TextStyle(
                            color: Colors.black38,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Consumer(
                          builder: (context, ref, child) {
                            final familyAsync = ref.watch(
                              familyDetailProvider(widget.familyId),
                            );
                            return familyAsync.when(
                              data: (family) {
                                return Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildVipBadge(
                                      ref,
                                      (userData['vip_level'] as num?)
                                              ?.toInt() ??
                                          0,
                                    ),
                                    if (family != null && family.tag != null)
                                      _buildFamilyTag(
                                        family.tag!,
                                        family.level,
                                      ),
                                  ],
                                );
                              },
                              loading: () => const SizedBox(),
                              error: (_, __) => const SizedBox(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 28,
                        ),
                        onPressed: () => _handleRequest(
                          request['id'],
                          request['user_id'],
                          true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: 28,
                        ),
                        onPressed: () => _handleRequest(
                          request['id'],
                          request['user_id'],
                          false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMembersTab() {
    final membersAsync = ref.watch(familyMembersProvider(widget.familyId));

    return membersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
      ),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: Colors.red)),
      data: (members) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final userData = member['users'] as Map<String, dynamic>;
            final role = member['role'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
              ),
              child: Row(
                children: [
                  _buildAvatar(
                    userData['avatar_url'],
                    50,
                    vipLevel: (userData['vip_level'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              userData['username'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildRoleChip(role),
                          ],
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final wealthLevel =
                                (userData['wealth_level'] as num?)?.toInt() ??
                                1;
                            final charmLevel =
                                (userData['charm_level'] as num?)?.toInt() ?? 1;
                            final familyAsync = ref.watch(
                              familyDetailProvider(widget.familyId),
                            );

                            return familyAsync.when(
                              data: (family) {
                                return Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildStackedBadge(
                                      ref: ref,
                                      level: wealthLevel,
                                      provider: wealthBadgeProvider,
                                    ),
                                    _buildStackedBadge(
                                      ref: ref,
                                      level: charmLevel,
                                      provider: charmBadgeProvider,
                                    ),
                                    if (family != null)
                                      _buildStackedBadge(
                                        ref: ref,
                                        level: family.level,
                                        provider: familyBadgeProvider,
                                      ),
                                    _buildVipBadge(
                                      ref,
                                      (userData['vip_level'] as num?)
                                              ?.toInt() ??
                                          0,
                                    ),
                                    if (family != null && family.tag != null)
                                      _buildFamilyTag(
                                        family.tag!,
                                        family.level,
                                      ),
                                  ],
                                );
                              },
                              loading: () => const SizedBox(),
                              error: (_, __) => const SizedBox(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final currentUserRole =
                          ref
                              .watch(userFamilyRoleProvider)
                              .value
                              ?.toLowerCase() ??
                          'member';
                      final familyAsync = ref.watch(userFamilyProvider).value;
                      final currentUserId = ref
                          .watch(userProfileProvider)
                          .value?['id'];

                      final isCreator = familyAsync?.creatorId == currentUserId;
                      final isTargetCreator =
                          familyAsync?.creatorId == userData['id'];

                      bool canManage = false;
                      if (currentUserId != userData['id']) {
                        if (isCreator) {
                          canManage = true;
                        } else if (currentUserRole == 'leader') {
                          if (!isTargetCreator) canManage = true;
                        } else if (currentUserRole == 'deputy') {
                          if (role.toLowerCase() == 'member') canManage = true;
                        }
                      }

                      if (!canManage) return const SizedBox();

                      return PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.black38,
                        ),
                        onSelected: (value) {
                          if (member['id'] != null && userData['id'] != null) {
                            _handleMemberAction(
                              member['id'],
                              userData['id'],
                              value,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (isCreator || currentUserRole == 'leader') ...[
                            PopupMenuItem(
                              value: 'leader',
                              child: Text(context.l10n.family_setLeader),
                            ),
                            const PopupMenuItem(
                              value: 'deputy',
                              child: Text('Set as Deputy'),
                            ),
                            const PopupMenuItem(
                              value: 'member',
                              child: Text('Set as Member'),
                            ),
                          ],
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              context.l10n.family_removeFromFamily,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRulesTab() {
    final configsAsync = ref.watch(familyLevelConfigsProvider);

    return configsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
      ),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: Colors.red)),
      data: (configs) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B61FF), Color(0xFF9C88FF)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Family Level',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Member Limit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Deputy Limit',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...configs.map((config) {
                      final lv = config['level'];
                      final isEven = lv % 2 == 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: isEven
                            ? Colors.black.withValues(alpha: 0.01)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.center,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF7B61FF,
                                    ).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'Lv.$lv',
                                  style: const TextStyle(
                                    color: Color(0xFF7B61FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${config['member_limit']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${config['deputy_limit']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? url, double size, {int vipLevel = 0}) {
    return Consumer(
      builder: (context, ref, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                color: Colors.grey[200],
              ),
              child: ClipOval(
                child: url != null && url.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.person, color: Colors.black12),
                      )
                    : const Icon(Icons.person, color: Colors.black12),
              ),
            ),
            if (vipLevel > 0)
              Consumer(
                builder: (context, ref, child) {
                  final frameAsync = ref.watch(vipFrameProvider(vipLevel));
                  return frameAsync.when(
                    data: (frameUrl) {
                      if (frameUrl == null) return const SizedBox();
                      return IgnorePointer(
                        child: SizedBox(
                          width: size * 1.5,
                          height: size * 1.5,
                          child: CachedNetworkImage(
                            imageUrl: frameUrl,
                            fit: BoxFit.contain,
                            errorWidget: (context, url, error) =>
                                const SizedBox(),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildRoleChip(String role) {
    Color color;
    String label;
    switch (role) {
      case 'leader':
        color = Colors.red[700]!;
        label = 'Leader';
        break;
      case 'deputy':
        color = Colors.orange[800]!;
        label = 'Deputy';
        break;
      default:
        color = Colors.blue[700]!;
        label = 'Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVipBadge(WidgetRef ref, int vipLevel) {
    if (vipLevel <= 0) return const SizedBox.shrink();

    final badgeAsync = ref.watch(vipBadgeProvider(vipLevel));
    return badgeAsync.when(
      data: (url) {
        if (url == null) return const SizedBox.shrink();
        return CachedNetworkImage(
          imageUrl: url,
          height: 14,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(width: 14, height: 14),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFamilyTag(String tag, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: (level > 50)
              ? [const Color(0xFFFFD700), const Color(0xFFB8860B)]
              : [const Color(0xFF00E5FF), const Color(0xFF00B8D4)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRoomTag(dynamic roomsData) {
    if (roomsData == null || (roomsData as List).isEmpty)
      return const SizedBox.shrink();

    final room = roomsData[0] as Map<String, dynamic>;
    final name = room['membership_tag_name'];
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    final colorStr = room['membership_tag_color'] ?? '#FF4081';
    final color = _parseHexColor(colorStr);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _parseHexColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildStackedBadge({
    required WidgetRef ref,
    required int level,
    required AutoDisposeFutureProvider<String?> Function(int) provider,
  }) {
    final badgeAsync = ref.watch(provider(level));

    return badgeAsync.when(
      data: (url) {
        if (url == null) return const SizedBox();
        return CachedNetworkImage(
          imageUrl: url,
          height: 22,
          placeholder: (context, url) => const SizedBox(width: 22, height: 22),
          errorWidget: (context, url, error) => const SizedBox(),
        );
      },
      loading: () => const SizedBox(width: 22, height: 22),
      error: (_, __) => const SizedBox(),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _handleRequest(
    String requestId,
    String userId,
    bool accept,
  ) async {
    try {
      await FamilyActions.respondToJoinRequest(
        requestId: requestId,
        userId: userId,
        familyId: widget.familyId,
        accept: accept,
      );
      ref.invalidate(familyJoinRequestsProvider(widget.familyId));
      ref.invalidate(familyMembersProvider(widget.familyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: accept ? Colors.green : Colors.red,
            content: Text(accept ? 'Request accepted' : 'Request rejected'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleMemberAction(
    String memberId,
    String userId,
    String action,
  ) async {
    try {
      if (action == 'remove') {
        await FamilyActions.removeMember(memberId: memberId, userId: userId);
      } else {
        await FamilyActions.updateMemberRole(
          memberId: memberId,
          newRole: action,
        );
      }
      ref.invalidate(familyMembersProvider(widget.familyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF7B61FF),
            content: Text('Member updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
