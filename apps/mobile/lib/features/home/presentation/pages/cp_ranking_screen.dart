import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/cp_ranking_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:go_router/go_router.dart';

class CPRankingScreen extends ConsumerStatefulWidget {
  const CPRankingScreen({super.key});

  @override
  ConsumerState<CPRankingScreen> createState() => _CPRankingScreenState();
}

class _CPRankingScreenState extends ConsumerState<CPRankingScreen> {
  int _selectedPeriodIndex = 0;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    DateTime end;

    if (_selectedPeriodIndex == 0) {
      end = DateTime(now.year, now.month, now.day + 1);
    } else if (_selectedPeriodIndex == 1) {
      int daysUntilSunday = 7 - now.weekday;
      end = DateTime(now.year, now.month, now.day + daysUntilSunday + 1);
    } else {
      end = DateTime(now.year, now.month + 1, 1);
    }

    if (mounted) {
      setState(() {
        _remainingTime = end.difference(now);
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          });
        }
      } else {
        _calculateRemainingTime();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = twoDigits(duration.inHours.remainder(24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${days}d ${hours}h ${minutes}m ${seconds}s";
  }

  @override
  Widget build(BuildContext context) {
    final periodTypes = ['day', 'week', 'month'];
    final rankingsAsync = ref.watch(
      cpRankingsProvider(periodTypes[_selectedPeriodIndex]),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/social/cp_nest_bg.webp',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFC0CB), Color(0xFFFFB6C1)],
                ),
              ),
            ),
          ),

          Container(color: Colors.black.withValues(alpha: 0.3)),

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
                      const Expanded(
                        child: Text(
                          'Couple Rankings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.help_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () => context.push('/cp-level'),
                      ),
                      const Icon(
                        Iconsax.search_normal,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        _buildTab('Day', 0),
                        _buildTab('Week', 1),
                        _buildTab('Month', 2),
                      ],
                    ),
                  ),
                ),

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.timer_1,
                        color: AppColors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${['Daily', 'Weekly', 'Monthly'][_selectedPeriodIndex]} Ends in: ${_formatDuration(_remainingTime)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: rankingsAsync.when(
                    data: (couples) {
                      if (couples.isEmpty) {
                        return const Center(
                          child: Text(
                            'No couple rankings found.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 350,
                              width: double.infinity,
                              child: Stack(
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.none,
                                children: [
                                  if (couples.isNotEmpty)
                                    Positioned(
                                      top: 75,
                                      child: _buildPodiumCoupleAvatars(
                                        couples[0],
                                        72,
                                        spacing: 1,
                                        hideInfo: true,
                                      ),
                                    ),
                                  if (couples.length > 1)
                                    Positioned(
                                      left: 15,
                                      top: 135,
                                      child: _buildPodiumCoupleAvatars(
                                        couples[1],
                                        65,
                                        spacing: 0,
                                        hideInfo: true,
                                      ),
                                    ),
                                  if (couples.length > 2)
                                    Positioned(
                                      right: 15,
                                      top: 135,
                                      child: _buildPodiumCoupleAvatars(
                                        couples[2],
                                        65,
                                        spacing: 0,
                                        hideInfo: true,
                                      ),
                                    ),

                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Image.asset(
                                        'assets/social/cp_frame.webp',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  if (couples.isNotEmpty)
                                    Positioned(
                                      top: 75,
                                      child: _buildPodiumCoupleAvatars(
                                        couples[0],
                                        72,
                                        spacing: 1,
                                        hideAvatars: true,
                                      ),
                                    ),
                                  if (couples.length > 1)
                                    Positioned(
                                      left: 15,
                                      top: 135,
                                      child: _buildPodiumCoupleAvatars(
                                        couples[1],
                                        65,
                                        spacing: 0,
                                        hideAvatars: true,
                                      ),
                                    ),
                                  if (couples.length > 2)
                                    Positioned(
                                      right: 15,
                                      top: 135,
                                      child: _buildPodiumCoupleAvatars(
                                        couples[2],
                                        65,
                                        spacing: 0,
                                        hideAvatars: true,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Column(
                                children: couples
                                    .asMap()
                                    .entries
                                    .where((entry) => entry.key >= 3)
                                    .map((entry) {
                                      return _buildCoupleListItem(
                                        entry.value,
                                        entry.key + 1,
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCoupleAvatars(
    CPRankingModel couple,
    double avatarSize, {
    double spacing = 4,
    bool hideAvatars = false,
    bool hideInfo = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: hideAvatars ? 0.0 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => NavigationUtils.navigateToProfile(
                  context,
                  ref,
                  couple.user1Id,
                ),
                child: _buildAvatar(couple.user1Avatar, avatarSize * 0.8),
              ),
              SizedBox(width: spacing),
              GestureDetector(
                onTap: () => NavigationUtils.navigateToProfile(
                  context,
                  ref,
                  couple.user2Id,
                ),
                child: _buildAvatar(couple.user2Avatar, avatarSize * 0.8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 19),
        Opacity(
          opacity: hideInfo ? 0.0 : 1.0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '${couple.user1Name ?? 'User'} & ${couple.user2Name ?? 'User'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              _buildCPLevelBadge(couple.score),
              const SizedBox(height: 5),
              Text(
                '${couple.score}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedPeriodIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriodIndex = index;
            _calculateRemainingTime();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black26, blurRadius: 4)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.pinkAccent : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(blurRadius: 10, color: Colors.pink.withValues(alpha: 0.3)),
        ],
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[800]),
              )
            : Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildCPLevelBadge(int score) {
    final badgeAsync = ref.watch(cpBadgeProvider(score));

    return badgeAsync.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final url = data['badge_url'] as String?;

        if (url == null) {
          return const SizedBox.shrink();
        }

        return CachedNetworkImage(
          imageUrl: url,
          height: 20,
          fit: BoxFit.contain,
          placeholder: (context, url) => const SizedBox(width: 20),
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(width: 20),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCoupleListItem(CPRankingModel couple, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 95,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/social/cp_list.webp'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 35,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 45,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => NavigationUtils.navigateToProfile(
                    context,
                    ref,
                    couple.user1Id,
                  ),
                  child: _buildAvatar(couple.user1Avatar, 40),
                ),
                const SizedBox(height: 4),
                Text(
                  couple.user1Name ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCPLevelBadge(couple.score),
                const SizedBox(height: 2),
                Text(
                  couple.score.toString(),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Text(
                  'Score',
                  style: TextStyle(color: Colors.white38, fontSize: 8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 52),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SizedBox(
              width: 45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => NavigationUtils.navigateToProfile(
                      context,
                      ref,
                      couple.user2Id,
                    ),
                    child: _buildAvatar(couple.user2Avatar, 40),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    couple.user2Name ?? 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
