import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/providers/cp_nest_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class CPLevelScreen extends ConsumerStatefulWidget {
  const CPLevelScreen({super.key});

  @override
  ConsumerState<CPLevelScreen> createState() => _CPLevelScreenState();
}

class _CPLevelScreenState extends ConsumerState<CPLevelScreen> {
  List<Map<String, dynamic>> _levelConfigs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLevelConfigs();
  }

  Future<void> _fetchLevelConfigs() async {
    try {
      final response = await Supabase.instance.client
          .from('cp_level_configs')
          .select()
          .order('level', ascending: true);

      if (mounted) {
        setState(() {
          _levelConfigs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CP_LEVEL_SCREEN] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(currentCoupleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.l10n.level_cpTitle,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.pinkAccent),
            )
          : coupleAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.pinkAccent),
              ),
              error: (e, _) => asyncErrorWidget(
                e,
                style: const TextStyle(color: Colors.white),
              ),
              data: (couple) {
                final int currentLevel =
                    (couple?['cp_level'] as num?)?.toInt() ?? 0;
                final num currentExp = couple?['cp_exp'] as num? ?? 0;

                Map<String, dynamic>? nextLevelConfig;
                Map<String, dynamic>? currentLevelConfig;

                for (var config in _levelConfigs) {
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
                    nextLevelConfig?['min_exp'] ?? (currentExp + 1000);
                final num prevExp = currentLevelConfig?['min_exp'] ?? 0;
                final num expToNext = nextExp - currentExp;
                final double progress = _calculateProgress(
                  currentExp,
                  prevExp,
                  nextExp,
                );

                return RefreshIndicator(
                  onRefresh: _fetchLevelConfigs,
                  color: Colors.pinkAccent,
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
                            _buildPrivilegesSection(currentLevel),
                            const SizedBox(height: 30),
                            _buildDescriptionSection(),
                            const SizedBox(height: 30),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
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
                      _buildLevelListSliver(),
                      const SliverToBoxAdapter(child: SizedBox(height: 50)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  double _calculateProgress(num current, num min, num next) {
    if (next <= min) return 1.0;
    return ((current - min) / (next - min)).clamp(0.0, 1.0);
  }

  Widget _buildTopSection(int level, Map<String, dynamic>? config) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 300,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.pinkAccent.withValues(alpha: 0.1),
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
                  height: 120,
                  placeholder: (context, url) =>
                      const SizedBox(height: 120, width: 120),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.favorite,
                    color: Colors.pinkAccent,
                    size: 80,
                  ),
                )
              else
                const Icon(
                  Icons.favorite_border,
                  color: Colors.white24,
                  size: 80,
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.pinkAccent, Colors.redAccent],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  'CP Level $level',
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
                'CP Value ${NumberFormat.compact().format(currentExp)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (expToNext > 0)
                Text(
                  'Still need ${NumberFormat.compact().format(expToNext)} to upgrade',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.pinkAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegesSection(int currentLevel) {
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
                  'CP Badge',
                  'Lv.1 Unlock',
                  Icons.verified,
                  true,
                  onTap: () => _showCPBadgesDialog(),
                ),
                _buildPrivilegeCard(
                  'CP Frame',
                  'Lv.5 Unlock',
                  Icons.portrait,
                  currentLevel >= 5,
                  onTap: () => _showCPFramesDialog(),
                ),
                _buildPrivilegeCard(
                  'Love Entrance',
                  'Lv.10 Unlock',
                  Icons.flash_on,
                  currentLevel >= 10,
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

  void _showCPBadgesDialog() {
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
                    'CP Badges are displayed on your profile and in rooms to show your relationship bond. Higher levels unlock more noble badges.',
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
                    itemCount: _levelConfigs.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey[100], height: 1),
                    itemBuilder: (context, index) {
                      final config = _levelConfigs[index];
                      final level = config['level'];
                      final badgeUrl = config['badge_url'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reach CP Lv.$level',
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
                                      Icons.favorite,
                                      color: Colors.pinkAccent,
                                    ),
                              )
                            else
                              const Icon(
                                Icons.favorite_border,
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

  void _showCPFramesDialog() {
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
                    'Exclusive CP Frames encircle your avatar in rooms and lists. These are prestigious rewards for dedicated couples.',
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
                    itemCount: _levelConfigs.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey[100], height: 1),
                    itemBuilder: (context, index) {
                      final config = _levelConfigs[index];
                      final level = config['level'];
                      final frameUrl = config['frame_url'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reach CP Lv.$level',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (frameUrl != null)
                              CachedNetworkImage(
                                imageUrl: frameUrl,
                                height: 45,
                                width: 45,
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.portrait,
                                      color: Colors.pinkAccent,
                                    ),
                              )
                            else
                              const Icon(Icons.portrait, color: Colors.grey),
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
                ? Colors.pinkAccent.withValues(alpha: 0.3)
                : Colors.white10,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isUnlocked ? Colors.pinkAccent : Colors.white24,
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
                color: isUnlocked ? Colors.pinkAccent : Colors.white24,
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
            'Improve your CP level by sending gifts to each other and spending time together in rooms. Higher CP levels unlock more exclusive rewards and noble status indicators.',
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
                'Min CP Value',
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

  Widget _buildLevelListSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final config = _levelConfigs[index];
          final level = config['level'];
          final minExp = config['min_exp'];
          int needs = 0;
          if (index + 1 < _levelConfigs.length) {
            needs =
                (_levelConfigs[index + 1]['min_exp'] as num).toInt() -
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
                            Icons.favorite,
                            color: Colors.pinkAccent,
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
        }, childCount: _levelConfigs.length),
      ),
    );
  }
}
