import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/family_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyLevelScreen extends ConsumerStatefulWidget {
  const FamilyLevelScreen({super.key});

  @override
  ConsumerState<FamilyLevelScreen> createState() => _FamilyLevelScreenState();
}

class _FamilyLevelScreenState extends ConsumerState<FamilyLevelScreen> {
  List<Map<String, dynamic>> _levelConfigs = [];

  @override
  void initState() {
    super.initState();
    _fetchLevelConfigs();
  }

  Future<void> _fetchLevelConfigs() async {
    debugPrint('[FAMILY_LEVEL_SCREEN] Fetching level configs...');
    try {
      final response = await Supabase.instance.client
          .from('family_level_configs')
          .select('*, family_level_assets(*)')
          .order('level', ascending: true);

      debugPrint('[FAMILY_LEVEL_SCREEN] Fetched ${response.length} configs');

      if (mounted) {
        setState(() {
          _levelConfigs = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('[FAMILY_LEVEL_SCREEN] Error fetching level configs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(userFamilyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A191E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Family level',
          style: TextStyle(
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
      body: familyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
        error: (e, stack) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (family) {
          if (_levelConfigs.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            );
          }

          final int currentLevel = family?.level ?? 1;
          final num currentExp = family?.totalExp ?? 0;

          Map<String, dynamic>? nextLevelConfig;
          Map<String, dynamic>? prevLevelConfig;

          for (var config in _levelConfigs) {
            final lvl = config['level'] as int? ?? 0;
            if (lvl > currentLevel) {
              nextLevelConfig = config;
              break;
            }
            if (lvl == currentLevel) {
              prevLevelConfig = config;
            }
          }

          final num nextExp =
              nextLevelConfig?['min_exp'] ?? (currentExp + 1000);
          final num prevExp = prevLevelConfig?['min_exp'] ?? 0;
          final num expToNext = nextExp - currentExp;
          final double progress = _calculateProgress(
            currentExp,
            prevExp,
            nextExp,
          ).toDouble();

          return RefreshIndicator(
            onRefresh: _fetchLevelConfigs,
            color: Colors.tealAccent,
            backgroundColor: const Color(0xFF0A191E),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildTopSection(currentLevel, prevLevelConfig),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Family EXP $currentExp',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Still need ${expToNext.clamp(0, double.infinity).toInt()} to upgrade',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
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
                                  Colors.tealAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildPrivilegesSection(currentLevel),
                      const SizedBox(height: 30),
                      _buildDescriptionSection(),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          context.l10n.family_experienceRequirements,
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

  Widget _buildTopSection(int level, Map<String, dynamic>? currentLevelConfig) {
    final assets = currentLevelConfig?['family_level_assets'] as List?;
    final badgeUrl = assets?.firstWhere(
      (a) => a['feature_key'] == 'badge',
      orElse: () => null,
    )?['image_url'];

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
                    Colors.tealAccent.withOpacity(0.1),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              width: 250,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(125, 20),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.tealAccent.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badgeUrl != null)
                CachedNetworkImage(
                  imageUrl: badgeUrl,
                  height: 120,
                  placeholder: (context, url) =>
                      const SizedBox(height: 120, width: 120),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.group,
                    color: Colors.tealAccent,
                    size: 80,
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF008080),
                        Color(0xFF004D40),
                        Color(0xFF002424),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'F',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  context.l10n.family_levelLabel(level),
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
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
          const Text(
            'Privileges of Levels',
            style: TextStyle(
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
                  'Family Badge',
                  'Lv.1 Unlock',
                  Icons.workspace_premium,
                  true,
                  onTap: () => _showLevelIconsDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
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
        width: 100,
        height: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked
                ? Colors.tealAccent.withOpacity(0.2)
                : Colors.white10,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isUnlocked ? Colors.tealAccent : Colors.white24,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
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
                color: isUnlocked ? Colors.tealAccent : Colors.white24,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelIconsDialog() {
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    'Family badges are displayed next to your name and in the family center. High-level families have more unique and prestigious badges.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
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
                      final rangeConfig = _levelConfigs.firstWhere((l) {
                        final assets = l['family_level_assets'] as List?;
                        return l['level'] >= start &&
                            l['level'] <= end &&
                            assets != null &&
                            assets.any((a) => a['feature_key'] == 'badge');
                      }, orElse: () => {});
                      final assets =
                          rangeConfig['family_level_assets'] as List?;
                      final badgeUrl = assets?.firstWhere(
                        (a) => a['feature_key'] == 'badge',
                        orElse: () => null,
                      )?['image_url'];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reach Lv.$start~$end',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (badgeUrl != null)
                              CachedNetworkImage(
                                imageUrl: badgeUrl,
                                height: 32,
                                placeholder: (context, url) => Container(
                                  width: 32,
                                  height: 32,
                                  color: Colors.grey[100],
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.workspace_premium,
                                      color: Colors.teal,
                                    ),
                              )
                            else
                              const Icon(
                                Icons.workspace_premium,
                                color: Colors.teal,
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

  Widget _buildDescriptionSection() {
    return const Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description of Levels',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Family levels represent the growth and activity of your family. Contributing EXP through room activity, gifts, and daily tasks increases your family level, unlocking exclusive badges for all members.',
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
          color: Colors.white.withOpacity(0.05),
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
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Exp Req',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Member Limit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Deputy Limit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
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
          final config = index < _levelConfigs.length
              ? _levelConfigs[index]
              : null;
          if (config == null) return const SizedBox();

          final level = config['level'];
          final minExp = config['min_exp'];
          int needs = 0;
          if (index + 1 < _levelConfigs.length) {
            needs = _levelConfigs[index + 1]['min_exp'] - minExp;
          }

          final assets = config['family_level_assets'] as List?;
          final badgeUrl = assets?.firstWhere(
            (a) => a['feature_key'] == 'badge',
            orElse: () => null,
          )?['image_url'];

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: Border(
                left: const BorderSide(color: Colors.white10),
                right: const BorderSide(color: Colors.white10),
                bottom: const BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (badgeUrl != null)
                        CachedNetworkImage(
                          imageUrl: badgeUrl,
                          height: 24,
                          width: 24,
                          placeholder: (context, url) =>
                              const SizedBox(width: 24, height: 24),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.group,
                            color: Colors.tealAccent,
                            size: 16,
                          ),
                        )
                      else
                        Text(
                          'Lv.$level',
                          textAlign: TextAlign.center,
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
                    '$minExp',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${config['member_limit'] ?? '-'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '${config['deputy_limit'] ?? '-'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
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
