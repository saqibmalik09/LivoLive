import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

final roomStatsProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  roomId,
) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('room_stats')
      .select()
      .eq('room_id', roomId)
      .maybeSingle();
});

final roomLevelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final configs = await supabase
      .from('room_level_configs')
      .select()
      .order('level', ascending: true);

  bool hasBadges = configs.any((c) => c['badge_url'] != null);
  if (!hasBadges) {
    final wealthConfigs = await supabase
        .from('level_configs')
        .select('level, badge_url')
        .eq('category', 'user_wealth')
        .order('level', ascending: true);

    for (var i = 0; i < configs.length; i++) {
      if (i < wealthConfigs.length) {
        configs[i]['badge_url'] = wealthConfigs[i]['badge_url'];
      }
    }
  }
  return configs;
});

class RoomLevelScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomLevelScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomLevelScreen> createState() => _RoomLevelScreenState();
}

class _RoomLevelScreenState extends ConsumerState<RoomLevelScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(roomStatsProvider(widget.roomId));
    final configsAsync = ref.watch(roomLevelConfigsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.l10n.level_roomTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
        error: (e, _) =>
            asyncErrorWidget(e, style: const TextStyle(color: Colors.white)),
        data: (stats) {
          return configsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            ),
            error: (e, _) => asyncErrorWidget(
              e,
              style: const TextStyle(color: Colors.white),
            ),
            data: (configs) {
              final int currentLevel =
                  (stats?['current_level'] as num?)?.toInt() ?? 1;
              final num currentExp = (stats?['total_exp'] as num?) ?? 0;

              Map<String, dynamic>? nextLevelConfig;
              Map<String, dynamic>? currentLevelConfig;

              for (var config in configs) {
                final lvl = config['level'] as int? ?? 0;
                if (lvl > currentLevel) {
                  nextLevelConfig = config;
                  break;
                }
                if (lvl == currentLevel) {
                  currentLevelConfig = config;
                }
              }

              final num nextExp =
                  nextLevelConfig?['min_exp'] ?? (currentExp + 5000);
              final num prevExp = currentLevelConfig?['min_exp'] ?? 0;
              final num expToNext = nextExp - currentExp;

              double progress = 0.0;
              if (nextExp > prevExp) {
                progress = ((currentExp - prevExp) / (nextExp - prevExp)).clamp(
                  0.0,
                  1.0,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(roomStatsProvider(widget.roomId));
                  ref.invalidate(roomLevelConfigsProvider);
                },
                color: Colors.orangeAccent,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildTopSection(currentLevel, currentLevelConfig),
                          _buildProgressSection(
                            currentExp,
                            expToNext,
                            progress,
                          ),
                          const SizedBox(height: 30),
                          _buildPrivilegesSection(currentLevel, configs),
                          const SizedBox(height: 30),
                          _buildDescriptionSection(),
                          const SizedBox(height: 30),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              context.l10n.level_experienceRequirements,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildTableHeader(),
                        ],
                      ),
                    ),
                    _buildLevelListSliver(configs),
                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopSection(int level, Map<String, dynamic>? config) {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 300,
              height: 180,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.orangeAccent.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config != null && config['badge_url'] != null)
                CachedNetworkImage(
                  imageUrl: config['badge_url'],
                  height: 100,
                  placeholder: (context, url) =>
                      const SizedBox(height: 100, width: 100),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.meeting_room,
                    color: Colors.orangeAccent,
                    size: 70,
                  ),
                )
              else
                const Icon(Icons.meeting_room, color: Colors.white24, size: 70),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrangeAccent],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  'Room Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(num currentExp, num expToNext, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room Exp ${NumberFormat.compact().format(currentExp)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (expToNext > 0)
                Text(
                  '${NumberFormat.compact().format(expToNext)} to upgrade',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.orangeAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegesSection(
    int currentLevel,
    List<Map<String, dynamic>> configs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.level_privileges,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPrivilegeCard(
                  'Room Badge',
                  'Level Badge',
                  Icons.verified,
                  true,
                  onTap: () => _showBadgesDialog(configs),
                ),
                _buildPrivilegeCard(
                  context.l10n.level_comingSoon,
                  '...',
                  Icons.more_horiz,
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgesDialog(List<Map<String, dynamic>> configs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    'Room Badges indicate the activity and status of the room. Upgrade your room level to unlock more prestigious badges.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 10,
                    ),
                    itemCount: 10,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey[100], height: 1),
                    itemBuilder: (context, index) {
                      final start = index == 0 ? 1 : index * 10;
                      final end = index == 0 ? 9 : (index * 10) + 9;

                      final rangeConfig = configs.firstWhere(
                        (l) =>
                            l['level'] >= start &&
                            l['level'] <= end &&
                            l['badge_url'] != null,
                        orElse: () => <String, dynamic>{},
                      );

                      final badgeUrl = rangeConfig['badge_url'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Level $start~$end',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (badgeUrl != null)
                              CachedNetworkImage(
                                imageUrl: badgeUrl,
                                height: 35,
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.meeting_room,
                                      color: Colors.orangeAccent,
                                    ),
                              )
                            else
                              const Icon(
                                Icons.meeting_room_outlined,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPrivilegeCard(
    String title,
    String subtitle,
    IconData icon,
    bool isUnlocked, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isUnlocked
                ? Colors.orangeAccent.withValues(alpha: 0.3)
                : Colors.white10,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isUnlocked ? Colors.orangeAccent : Colors.white24,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isUnlocked ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isUnlocked ? Colors.orangeAccent : Colors.white24,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Room levels are upgraded by receiving gifts and having active members in the room. Higher levels showcase the room\'s popularity and prestige.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Level',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Min Exp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Upgrade Needs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelListSliver(List<Map<String, dynamic>> configs) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final config = configs[index];
          final level = config['level'];
          final minExp = config['min_exp'];
          int needs = 0;
          if (index + 1 < configs.length) {
            needs =
                (configs[index + 1]['min_exp'] as num).toInt() -
                (minExp as num).toInt();
          }

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              border: const Border(
                left: BorderSide(color: Colors.white10),
                right: BorderSide(color: Colors.white10),
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (config['badge_url'] != null)
                        CachedNetworkImage(
                          imageUrl: config['badge_url'],
                          height: 24,
                          width: 24,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.meeting_room,
                            color: Colors.orangeAccent,
                            size: 16,
                          ),
                        )
                      else
                        Text(
                          'Lv.$level',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    NumberFormat.compact().format(minExp),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    needs > 0 ? NumberFormat.compact().format(needs) : '-',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }, childCount: configs.length),
      ),
    );
  }
}
