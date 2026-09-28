import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/family_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/features/home/presentation/pages/create_family_screen.dart';
import 'package:sk_live/features/home/presentation/pages/join_family_screen.dart';
import 'package:sk_live/features/home/presentation/pages/family_level_screen.dart';
import 'package:sk_live/features/home/presentation/pages/family_management_screen.dart';

class FamilyCenterScreen extends ConsumerStatefulWidget {
  const FamilyCenterScreen({super.key});

  @override
  ConsumerState<FamilyCenterScreen> createState() => _FamilyCenterScreenState();
}

class _FamilyCenterScreenState extends ConsumerState<FamilyCenterScreen> {
  String _selectedPeriod = 'Week';
  Timer? _timer;
  Duration _remainingTime = const Duration(
    days: 7,
    hours: 10,
    minutes: 39,
    seconds: 9,
  );

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          });
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = twoDigits(duration.inHours.remainder(24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$days Day $hours:$minutes:$seconds';
  }

  String _formatExp(int exp) {
    if (exp >= 1000000) return '${(exp / 1000000).toStringAsFixed(2)} M';
    if (exp >= 1000) return '${(exp / 1000).toStringAsFixed(1)} k';
    return exp.toString();
  }

  Widget _buildAvatar(String? url, double size) {
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: Icon(Icons.person, color: Colors.white, size: size * 0.6),
      );
    }

    final isSvg = url.toLowerCase().contains('.svg');

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isSvg
            ? SvgPicture.network(
                url,
                fit: BoxFit.cover,
                placeholderBuilder: (context) =>
                    Container(color: Colors.grey[800]),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topFamiliesAsync = ref.watch(topFamiliesProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/social/family_bg.jpeg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: const Color(0xFF1A1A1A)),
          ),

          Container(color: Colors.black.withValues(alpha: 0.4)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.family_centerTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(
                        Iconsax.search_normal,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.help_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FamilyLevelScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Consumer(
                  builder: (context, ref, child) {
                    final familyAsync = ref.watch(userFamilyProvider);
                    final configsAsync = ref.watch(familyLevelConfigsProvider);

                    return familyAsync.when(
                      data: (family) {
                        if (family == null) return const SizedBox.shrink();

                        return configsAsync.when(
                          data: (configs) {
                            final int currentLevel = family.level;
                            final int currentExp = family.totalExp;

                            final currentConfig = configs.firstWhere(
                              (c) => c['level'] == currentLevel,
                              orElse: () => <String, dynamic>{'min_exp': 0},
                            );

                            final nextConfig = configs.firstWhere(
                              (c) => c['level'] == currentLevel + 1,
                              orElse: () => <String, dynamic>{},
                            );

                            final int minExp = (currentConfig['min_exp'] as num)
                                .toInt();
                            final int? nextMinExp = nextConfig.isNotEmpty
                                ? (nextConfig['min_exp'] as num).toInt()
                                : null;

                            double progress = 0.0;
                            if (nextMinExp != null) {
                              progress =
                                  (currentExp - minExp) / (nextMinExp - minExp);
                            } else {
                              progress = 1.0;
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  _buildAvatar(family.avatarUrl, 45),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              family.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF00C9FF),
                                                    Color(0xFF92FE9D),
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Lv.${family.level}',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: progress.clamp(0.0, 1.0),
                                            minHeight: 6,
                                            backgroundColor: Colors.white10,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Color(0xFF92FE9D)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          nextMinExp != null
                                              ? 'EXP: $currentExp / $nextMinExp'
                                              : 'MAX LEVEL',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const FamilyLevelScreen(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (e, _) => const SizedBox.shrink(),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _buildPeriodTab('Day', _selectedPeriod == 'Day'),
                        _buildPeriodTab('Week', _selectedPeriod == 'Week'),
                        _buildPeriodTab('Month', _selectedPeriod == 'Month'),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: AppColors.gold,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ends in: ${_formatDuration(_remainingTime)}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: topFamiliesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                    error: (e, st) => Center(
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    data: (realFamilies) {
                      if (realFamilies.isEmpty) {
                        return const Center(
                          child: Text(
                            'No families found. Be the first to create one!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final displayData = realFamilies
                          .map(
                            (f) => {
                              'name': f.name,
                              'exp': _formatExp(f.totalExp),
                              'tag': f.tag,
                              'leader': f.leaderName ?? 'Unknown',
                              'avatarUrl': f.avatarUrl,
                              'level': f.level,
                            },
                          )
                          .toList();

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            if (displayData.isNotEmpty)
                              SizedBox(
                                height: 320,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    if (displayData.length > 1)
                                      Positioned(
                                        left: 0,
                                        bottom: 20,
                                        child: _buildPodiumCard(
                                          rank: 2,
                                          data: displayData[1],
                                          height: 180,
                                          color: Colors.blueAccent,
                                          totalExp: realFamilies[1].totalExp,
                                        ),
                                      ),
                                    if (displayData.length > 2)
                                      Positioned(
                                        right: 0,
                                        bottom: 20,
                                        child: _buildPodiumCard(
                                          rank: 3,
                                          data: displayData[2],
                                          height: 180,
                                          color: Colors.orangeAccent,
                                          totalExp: realFamilies[2].totalExp,
                                        ),
                                      ),
                                    if (displayData.isNotEmpty)
                                      Positioned(
                                        top: 0,
                                        child: _buildPodiumCard(
                                          rank: 1,
                                          data: displayData[0],
                                          height: 260,
                                          color: Colors.redAccent,
                                          isFirst: true,
                                          totalExp: realFamilies[0].totalExp,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),

                            if (displayData.length > 3)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: displayData.length - 3,
                                itemBuilder: (context, index) {
                                  final rank = index + 4;
                                  final family = displayData[index + 3];
                                  return _buildListTile(rank, family);
                                },
                              ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 20,
                bottom: 25,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/social/family_bg.jpeg'),
                  fit: BoxFit.cover,
                  opacity: 0.1,
                ),
                color: Colors.black,
                border: Border(
                  top: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final familyAsync = ref.watch(userFamilyProvider);
                      final userRole = ref.watch(userFamilyRoleProvider).value;
                      final isLeader = userRole?.toLowerCase() == 'leader';

                      return familyAsync.when(
                        data: (family) {
                          if (family == null) {
                            return Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateFamilyScreen(),
                                      ),
                                    ),
                                    child: _buildOrnateButton('Create', const [
                                      Color(0xFF00A36C),
                                      Color(0xFF006B3C),
                                    ]),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const JoinFamilyScreen(),
                                      ),
                                    ),
                                    child: _buildOrnateButton('Join', const [
                                      Color(0xFFB8860B),
                                      Color(0xFF8B4513),
                                    ]),
                                  ),
                                ),
                              ],
                            );
                          }

                          if (isLeader) {
                            return Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateFamilyScreen(
                                          existingFamily: family,
                                        ),
                                      ),
                                    ),
                                    child: _buildOrnateButton(
                                      'Edit Family',
                                      const [
                                        Color(0xFF00A36C),
                                        Color(0xFF006B3C),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FamilyManagementScreen(
                                          familyId: family.id,
                                        ),
                                      ),
                                    ),
                                    child: _buildOrnateButton('Manage', const [
                                      Color(0xFF7B61FF),
                                      Color(0xFF5A45D1),
                                    ]),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    '👨‍👩‍👧  ${family.name}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1A1A2E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text(
                                        'Leave Family?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        'Are you sure you want to leave "${family.name}"? You can rejoin later by sending a new request.',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700],
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'Leave',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    try {
                                      await FamilyActions.leaveFamily(
                                        familyId: family.id,
                                      );
                                      ref.invalidate(userFamilyProvider);
                                      ref.invalidate(userProfileProvider);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFD32F2F),
                                        Color(0xFF8B0000),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.exit_to_app,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Leave',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(
                          height: 50,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final familyAsync = ref.watch(userFamilyProvider);
                      final userProfile = ref.watch(userProfileProvider).value;
                      return familyAsync.when(
                        data: (family) {
                          if (family == null) {
                            return const Text(
                              'You have not joined the family yet. Please create or join it first',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            );
                          }
                          final isOwner =
                              family.creatorId == userProfile?['id'];
                          return Text(
                            isOwner
                                ? 'You are the leader of ${family.name}'
                                : 'Member of ${family.name}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = label;
            if (label == 'Day') {
              _remainingTime = const Duration(
                hours: 23,
                minutes: 59,
                seconds: 59,
              );
            } else if (label == 'Week') {
              _remainingTime = const Duration(
                days: 6,
                hours: 23,
                minutes: 59,
                seconds: 59,
              );
            } else {
              _remainingTime = const Duration(
                days: 29,
                hours: 23,
                minutes: 59,
                seconds: 59,
              );
            }
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrnateButton(String label, List<Color> colors) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 8,
            child: Icon(
              Icons.circle,
              color: Colors.white.withValues(alpha: 0.2),
              size: 4,
            ),
          ),
          Positioned(
            right: 8,
            child: Icon(
              Icons.circle,
              color: Colors.white.withValues(alpha: 0.2),
              size: 4,
            ),
          ),
          Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard({
    required int rank,
    required Map<String, dynamic> data,
    required double height,
    required Color color,
    required int totalExp,
    bool isFirst = false,
  }) {
    String frameAsset = 'assets/ranking/rank_${rank}_frame.webp';

    return SizedBox(
      width: isFirst ? 160 : 130,
      height: height,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: isFirst ? 85 : 65,
            child: _buildAvatar(data['avatarUrl'], isFirst ? 65 : 55),
          ),

          Positioned.fill(
            child: Image.asset(
              frameAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: color.withValues(alpha: 0.1)),
            ),
          ),

          Positioned(
            bottom: isFirst ? 25 : -5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isFirst ? 15 : 13,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (data['tag'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: ClipPath(
                            clipper: TagRibbonClipper(),
                            child: Container(
                              height: 15,
                              constraints: const BoxConstraints(maxWidth: 80),
                              padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: (totalExp > 10000000)
                                      ? [
                                          const Color(0xFFFFD700),
                                          const Color(0xFFB8860B),
                                        ]
                                      : [
                                          const Color(0xFF00E5FF),
                                          const Color(0xFF00B8D4),
                                        ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  data['tag'].toString().length > 6
                                      ? '${data['tag'].toString().substring(0, 6)}...'
                                      : data['tag'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Consumer(
                        builder: (context, ref, child) {
                          final badgeAsync = ref.watch(
                            familyBadgeProvider(
                              int.tryParse(data['level'].toString()) ?? 1,
                            ),
                          );
                          return badgeAsync.when(
                            data: (url) {
                              if (url == null)
                                return const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.white,
                                  size: 20,
                                );
                              return CachedNetworkImage(
                                imageUrl: url,
                                height: 24,
                                width: 24,
                                fit: BoxFit.contain,
                              );
                            },
                            loading: () => const SizedBox(width: 24),
                            error: (_, _) => const Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 0.5),
                      ),
                      child: const Text(
                        'EXP',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data['exp'],
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (data['leader'] != 'Unknown')
                  Text(
                    'Leader: ${data['leader']}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(int rank, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              rank.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          _buildAvatar(data['avatarUrl'], 50),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (data['tag'] != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: ClipPath(
                            clipper: TagRibbonClipper(),
                            child: Container(
                              height: 15,
                              constraints: const BoxConstraints(maxWidth: 90),
                              padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF00E5FF),
                                    Color(0xFF00B8D4),
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  data['tag'].toString().length > 6
                                      ? '${data['tag'].toString().substring(0, 6)}...'
                                      : data['tag'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Consumer(
                        builder: (context, ref, child) {
                          final badgeAsync = ref.watch(
                            familyBadgeProvider(
                              int.tryParse(data['level'].toString()) ?? 1,
                            ),
                          );
                          return badgeAsync.when(
                            data: (url) {
                              if (url == null)
                                return const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.white,
                                  size: 20,
                                );
                              return CachedNetworkImage(
                                imageUrl: url,
                                height: 24,
                                width: 24,
                                fit: BoxFit.contain,
                              );
                            },
                            loading: () => const SizedBox(width: 24),
                            error: (_, _) => const Icon(
                              Icons.workspace_premium,
                              color: Colors.white,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (data['leader'] != 'Unknown')
                  Text(
                    'Leader: ${data['leader']}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'EXP',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data['exp'],
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TagRibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double radius = 4;
    double pointWidth = 6;

    path.moveTo(radius, 0);
    path.lineTo(size.width - pointWidth - radius, 0);
    path.quadraticBezierTo(
      size.width - pointWidth,
      0,
      size.width - (pointWidth / 2),
      size.height / 4,
    );
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - (pointWidth / 2), size.height * 0.75);
    path.quadraticBezierTo(
      size.width - pointWidth,
      size.height,
      size.width - pointWidth - radius,
      size.height,
    );
    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
