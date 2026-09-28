import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/agency_ranking_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/room_info_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/widgets/ranking_frame_media.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/features/home/presentation/widgets/agency_level_nameplate.dart';

class GiftCenterScreen extends ConsumerStatefulWidget {
  final int initialPage;
  final String initialPeriod;
  const GiftCenterScreen({
    super.key,
    this.initialPage = 0,
    this.initialPeriod = 'Week',
  });

  @override
  ConsumerState<GiftCenterScreen> createState() => _GiftCenterScreenState();
}

class _GiftCenterScreenState extends ConsumerState<GiftCenterScreen> {
  late String _selectedPeriod;
  late Timer _timer;
  Duration _timeRemaining = Duration.zero;
  late PageController _mainPageController;
  late int _currentMainPage;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    _currentMainPage = widget.initialPage;
    _mainPageController = PageController(initialPage: widget.initialPage);
    _calculateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTimeRemaining();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _mainPageController.dispose();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    final now = DateTime.now();
    DateTime end;
    if (_selectedPeriod == 'Day') {
      end = DateTime(now.year, now.month, now.day + 1);
    } else if (_selectedPeriod == 'Week') {
      final daysUntilSunday = 7 - now.weekday;
      end = DateTime(now.year, now.month, now.day + daysUntilSunday + 1);
    } else {
      end = DateTime(now.year, now.month + 1, 1);
    }
    if (mounted) setState(() => _timeRemaining = end.difference(now));
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return days > 0
        ? "${days}d $hours:$minutes:$seconds"
        : "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _mainPageController,
            onPageChanged: (index) => setState(() => _currentMainPage = index),
            children: [
              _buildRankPage(
                'Gift',
                'assets/ranking/gift/gift_bg.jpeg',
                'assets/ranking/gift/gift_list.webp',
              ),
              _buildRankPage(
                'Charm',
                'assets/ranking/charm/charm_bg.webp',
                'assets/ranking/charm/charm_list.webp',
              ),
              _buildRankPage(
                'Room',
                'assets/room/room-bg.webp',
                'assets/room/room-list.webp',
              ),
              _buildAgencyRankPage(),
            ],
          ),
          SafeArea(child: _buildTopNav()),
        ],
      ),
    );
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNavButton('Wealth', 0),
                  const SizedBox(width: 18),
                  _buildNavButton('Charm', 1),
                  const SizedBox(width: 18),
                  _buildNavButton('Room', 2),
                  const SizedBox(width: 18),
                  _buildNavButton('Agency', 3),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.info_circle, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String title, int index) {
    final isSelected = _currentMainPage == index;
    return GestureDetector(
      onTap: () => _mainPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white60,
          fontSize: isSelected ? 18 : 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  GiftRankingModel _agencyToGiftRanking(AgencyRankingModel agency) {
    return GiftRankingModel(
      userId: agency.agencyId,
      username: agency.name,
      avatarUrl: agency.avatarUrl,
      score: agency.score,
      rank: agency.rank,
      rankBadge: agency.rankBadge,
      rankFrame: agency.rankFrame,
      agencyLevelBadgeUrl: agency.levelBadgeUrl,
    );
  }

  AsyncValue<List<GiftRankingModel>> _mapAgencyRankings(
    AsyncValue<List<AgencyRankingModel>> agencyAsync,
  ) {
    return agencyAsync.when(
      data: (list) => AsyncValue.data(list.map(_agencyToGiftRanking).toList()),
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
    );
  }

  Widget _buildAgencyRankPage() {
    final agencyAsync = ref.watch(agencyRankingsProvider(_selectedPeriod));
    return _buildRankPage(
      'Agency',
      'assets/ranking/agency/agency_bg.webp',
      'assets/ranking/agency/agency_list.webp',
      rankingsOverride: _mapAgencyRankings(agencyAsync),
    );
  }

  Widget _buildRankPage(
    String type,
    String bgPath,
    String listCardPath, {
    AsyncValue<List<GiftRankingModel>>? rankingsOverride,
  }) {
    final AsyncValue<List<GiftRankingModel>> rankingsAsync =
        rankingsOverride ??
        ref.watch(rankingsProvider((type, _selectedPeriod)));

    return Stack(
      children: [
        Positioned.fill(child: Image.asset(bgPath, fit: BoxFit.cover)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 60, bottom: 92),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPeriodTabs(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Iconsax.timer_1_copy,
                          color: AppColors.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ends in: ${_formatDuration(_timeRemaining)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  rankingsAsync.when(
                    loading: () {
                      debugPrint(
                        'DEBUG: Rankings Loading for $type ($_selectedPeriod)...',
                      );
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    },
                    error: (e, st) {
                      debugPrint('DEBUG ERROR in $type Rankings: $e');
                      return Center(
                        child: Text(
                          'Error: $e',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                    data: (rankings) {
                      debugPrint(
                        'DEBUG: Received ${rankings.length} $type rankings for $_selectedPeriod',
                      );
                      if (rankings.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: Text(
                            'No rankings found',
                            style: TextStyle(color: Colors.white60),
                          ),
                        );
                      }
                      final top3 = rankings.take(3).toList();
                      final others = rankings.skip(3).toList();
                      return Column(
                        children: [
                          _buildBannerCarousel(top3, type, ref),
                          const SizedBox(height: 20),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            itemCount: others.length,
                            itemBuilder: (context, index) => _buildRankingTile(
                              others[index],
                              index + 4,
                              listCardPath,
                              type,
                              ref,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        rankingsAsync.maybeWhen(
          data: (rankings) => Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMyRankBottomCard(type, rankings),
          ),
          orElse: () => Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMyRankBottomCard(type, const []),
          ),
        ),
      ],
    );
  }

  ({int displayRank, int score, int? targetRank, int pointsNeeded, bool isTop})
  _computeMyRankStats(List<GiftRankingModel> rankings, String? lookupId) {
    if (lookupId == null || lookupId.isEmpty) {
      return (
        displayRank: 0,
        score: 0,
        targetRank: rankings.isNotEmpty ? rankings.last.rank : null,
        pointsNeeded: rankings.isNotEmpty ? rankings.last.score + 1 : 1,
        isTop: false,
      );
    }

    final index = rankings.indexWhere((r) => r.userId == lookupId);
    if (index < 0) {
      if (rankings.isEmpty) {
        return (
          displayRank: 0,
          score: 0,
          targetRank: null,
          pointsNeeded: 1,
          isTop: false,
        );
      }
      final last = rankings.last;
      return (
        displayRank: 0,
        score: 0,
        targetRank: last.rank,
        pointsNeeded: last.score > 0 ? last.score + 1 : 1,
        isTop: false,
      );
    }

    final me = rankings[index];
    if (me.rank <= 1) {
      return (
        displayRank: me.rank,
        score: me.score,
        targetRank: null,
        pointsNeeded: 0,
        isTop: true,
      );
    }

    final above = rankings[index - 1];
    final pointsNeeded = (above.score - me.score) + 1;
    return (
      displayRank: me.rank,
      score: me.score,
      targetRank: above.rank,
      pointsNeeded: pointsNeeded.clamp(1, above.score + 1),
      isTop: false,
    );
  }

  Widget _buildCoinScore(int score, {double fontSize = 13, Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Iconsax.coin, color: Colors.white, size: 8),
        ),
        const SizedBox(width: 5),
        Text(
          NumberFormatter.format(score),
          style: TextStyle(
            color: color ?? AppColors.gold,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  Widget _buildRankingBadgeRow(
    String type, {
    int? userLevel,
    int? charmLevel,
    int? wealthLevel,
    int? roomLevel,
    String? rankBadge,
    String? agencyName,
    String? agencyLevelBadgeUrl,
  }) {
    if (type == 'Agency') {
      return AgencyLevelNameplate(
        agencyName: agencyName?.trim().isNotEmpty == true
            ? agencyName!.trim()
            : 'Agency',
        badgeUrl: agencyLevelBadgeUrl,
        height: 18,
        maxWidth: 120,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (type == 'Room') ...[
          _buildLevelBadge(roomLevel ?? 1, 'room'),
          const SizedBox(width: 4),
        ],
        if (type == 'Gift') ...[
          _buildLevelBadge(wealthLevel ?? 1, 'wealth'),
          const SizedBox(width: 4),
          _buildLevelBadge(charmLevel ?? userLevel ?? 1, 'charm'),
          const SizedBox(width: 4),
        ],
        if (type == 'Charm') ...[
          _buildLevelBadge(charmLevel ?? userLevel ?? 1, 'charm'),
          const SizedBox(width: 4),
          _buildLevelBadge(wealthLevel ?? 1, 'wealth'),
          const SizedBox(width: 4),
        ],
        if (rankBadge != null)
          _safeBadgeImage(rankBadge, height: 14, width: 28),
      ],
    );
  }

  Widget _buildMyRankBottomCard(String type, List<GiftRankingModel> rankings) {
    final profileAsync = ref.watch(userProfileProvider);
    final myRoomAsync = type == 'Room'
        ? ref.watch(roomInfoProvider(null))
        : null;
    final myAgencyAsync = type == 'Agency' ? ref.watch(myAgencyProvider) : null;

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        String? lookupId = profile['id'] as String?;
        String displayName = profile['username'] as String? ?? 'User';
        String? avatarUrl = profile['avatar_url'] as String?;
        final userLevel = (profile['user_level'] as num?)?.toInt() ?? 1;
        final charmLevel =
            (profile['charm_level'] as num?)?.toInt() ?? userLevel;
        final wealthLevel = (profile['wealth_level'] as num?)?.toInt() ?? 1;
        var roomLevel = 1;
        String? rankBadge;

        if (type == 'Room') {
          if (myRoomAsync?.isLoading == true) {
            return const SizedBox(height: 88);
          }
          final room = myRoomAsync?.value;
          if (room != null) {
            lookupId = room['id']?.toString();
            displayName = room['title'] as String? ?? displayName;
            avatarUrl = room['image_url'] as String? ?? avatarUrl;
            final stats = room['room_stats'];
            if (stats is Map) {
              roomLevel = (stats['level'] as num?)?.toInt() ?? roomLevel;
            }
            roomLevel = (room['current_level'] as num?)?.toInt() ?? roomLevel;
          }
        } else if (type == 'Agency') {
          if (myAgencyAsync?.isLoading == true) {
            return const SizedBox(height: 88);
          }
          final agency = myAgencyAsync?.value;
          if (agency != null) {
            lookupId = agency['id']?.toString();
            displayName = agency['name'] as String? ?? displayName;
          }
        }

        final meIndex = lookupId == null
            ? -1
            : rankings.indexWhere((r) => r.userId == lookupId);
        final meInList = meIndex >= 0 ? rankings[meIndex] : null;
        if (meInList != null) {
          rankBadge = meInList.rankBadge;
          roomLevel = meInList.roomLevel ?? roomLevel;
        }
        final rankFrame = meInList?.rankFrame;

        final stats = _computeMyRankStats(rankings, lookupId);
        final score = meInList?.score ?? stats.score;
        final displayRank = meInList?.rank ?? stats.displayRank;

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF8E7), Color(0xFFF0DDB8)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    displayRank > 0 ? '$displayRank' : '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF5C4A2A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: rankFrame != null && rankFrame.trim().isNotEmpty
                      ? 52
                      : 44,
                  height: rankFrame != null && rankFrame.trim().isNotEmpty
                      ? 52
                      : 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 2),
                        ),
                        child: ClipOval(
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: Colors.grey[300]),
                                  errorWidget: (_, __, ___) => Icon(
                                    _rankAvatarIcon(type),
                                    color: Colors.grey[600],
                                    size: 22,
                                  ),
                                )
                              : Icon(
                                  _rankAvatarIcon(type),
                                  color: Colors.grey[600],
                                  size: 22,
                                ),
                        ),
                      ),
                      if (rankFrame != null && rankFrame.trim().isNotEmpty)
                        RankingFrameMedia(
                          url: rankFrame,
                          width: 52,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF3D2F1A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRankingBadgeRow(
                        type,
                        userLevel: userLevel,
                        charmLevel: charmLevel,
                        wealthLevel: wealthLevel,
                        roomLevel: roomLevel,
                        rankBadge: rankBadge,
                        agencyName: displayName,
                        agencyLevelBadgeUrl: meInList?.agencyLevelBadgeUrl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCoinScore(
                      score,
                      fontSize: 15,
                      color: const Color(0xFFB8860B),
                    ),
                    if (!stats.isTop && stats.targetRank != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'To reach rank[${stats.targetRank}] : [${NumberFormatter.format(stats.pointsNeeded)}]',
                        style: TextStyle(
                          color: const Color(0xFF6B5A3E).withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (stats.isTop) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Top rank!',
                        style: TextStyle(
                          color: Color(0xFFB8860B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _rankAvatarIcon(String type) {
    if (type == 'Room') return Icons.meeting_room;
    if (type == 'Agency') return Icons.business;
    return Icons.person;
  }

  Widget _buildBannerCarousel(
    List<GiftRankingModel> top3,
    String type,
    WidgetRef ref,
  ) {
    final slots = List<GiftRankingModel?>.from(top3);
    while (slots.length < 3) {
      slots.add(null);
    }
    return Container(
      height: 305,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: const Offset(0, -42),
              child: _buildBannerItem(
                'assets/ranking/gift/banner_1.webp',
                198,
                slots[0],
                type,
                ref,
                textBottom: 50,
                avatarScale: 0.32,
                avatarTopFactor: 0.05,
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 20,
            child: _buildBannerItem(
              'assets/ranking/gift/banner_2.webp',
              186,
              slots.length > 1 ? slots[1] : null,
              type,
              ref,
              textBottom: 62,
              avatarTopFactor: 0.05,
            ),
          ),
          Positioned(
            right: 10,
            bottom: 20,
            child: _buildBannerItem(
              'assets/ranking/gift/banner_3.webp',
              186,
              slots.length > 2 ? slots[2] : null,
              type,
              ref,
              textBottom: 62,
              avatarTopFactor: 0.05,
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeBadgeImage(String? url, {double height = 16, double? width}) {
    if (url == null || url.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: width,
      height: height,
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        fit: BoxFit.contain,
        placeholder: (_, _) => SizedBox(width: width ?? height, height: height),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBannerItem(
    String path,
    double height,
    GiftRankingModel? user,
    String type,
    WidgetRef ref, {
    double textBottom = 65,
    double avatarTopFactor = 0.09,
    double avatarScale = 0.22,
  }) {
    return GestureDetector(
      onTap: () {
        if (user == null) return;
        if (type == 'Room') {
          openRoomLive(context, {
            'id': user.userId,
            'title': user.username,
            'image_url': user.avatarUrl,
          });
        } else if (type != 'Agency') {
          NavigationUtils.navigateToProfile(context, ref, user.userId);
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (user != null || true)
            Positioned(
              top: height * avatarTopFactor,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: height * avatarScale,
                    height: height * avatarScale,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black26,
                    ),
                    child: ClipOval(
                      child: user?.avatarUrl != null
                          ? CachedNetworkImage(
                              imageUrl: user!.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[800]),
                              errorWidget: (context, url, error) => Icon(
                                _rankAvatarIcon(type),
                                color: Colors.white,
                                size: 20,
                              ),
                            )
                          : Icon(
                              _rankAvatarIcon(type),
                              color: Colors.white10,
                              size: 40,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          Image.asset(path, height: height, fit: BoxFit.fitHeight),
          if (user != null)
            Positioned(
              bottom: textBottom,
              child: Column(
                children: [
                  SizedBox(
                    width: height * 0.28,
                    child: Text(
                      user.username,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (type == 'Agency')
                    AgencyLevelNameplate(
                      agencyName: user.username,
                      badgeUrl: user.agencyLevelBadgeUrl,
                      height: 16,
                      maxWidth: 96,
                    )
                  else if (user.rankBadge != null)
                    _safeBadgeImage(user.rankBadge, height: 18, width: 36),
                  const SizedBox(height: 2),
                  if (type == 'Room') ...[
                    _buildLevelBadge(user.roomLevel ?? 1, 'room'),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormatter.format(user.score),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ] else if (type == 'Gift') ...[
                    _buildLevelBadge(user.wealthLevel ?? 1, 'wealth'),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormatter.format(user.score),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ] else if (type == 'Charm') ...[
                    _buildLevelBadge(user.userLevel ?? 1, 'charm'),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormatter.format(user.score),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                          ),
                          child: const Icon(
                            Iconsax.coin,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          NumberFormatter.format(user.score),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: ['Day', 'Week', 'Month'].map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPeriod = period);
                _calculateTimeRemaining();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRankingTile(
    GiftRankingModel data,
    int rank,
    String cardPath,
    String type,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(cardPath),
                  fit: BoxFit.fill,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 88),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 6),
                          child: GestureDetector(
                            onTap: () {
                              if (type == 'Room') {
                                openRoomLive(context, {
                                  'id': data.userId,
                                  'title': data.username,
                                  'image_url': data.avatarUrl,
                                });
                              } else if (type != 'Agency') {
                                NavigationUtils.navigateToProfile(
                                  context,
                                  ref,
                                  data.userId,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.gold,
                                    Colors.yellow,
                                    Colors.orangeAccent,
                                    AppColors.gold,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black,
                                    ),
                                    child: ClipOval(
                                      child: data.avatarUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: data.avatarUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    color: Colors.grey[800],
                                                  ),
                                              errorWidget:
                                                  (context, url, error) => Icon(
                                                    _rankAvatarIcon(type),
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                            )
                                          : Icon(
                                              _rankAvatarIcon(type),
                                              color: Colors.white60,
                                              size: 20,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              _buildRankingBadgeRow(
                                type,
                                userLevel: data.userLevel,
                                charmLevel: data.charmLevel,
                                wealthLevel: data.wealthLevel,
                                roomLevel: data.roomLevel,
                                rankBadge: data.rankBadge,
                                agencyName: data.username,
                                agencyLevelBadgeUrl: data.agencyLevelBadgeUrl,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildCoinScore(data.score),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(int level, String category) {
    final badgeAsync = category == 'room'
        ? ref.watch(roomBadgeProvider(level))
        : (category == 'wealth'
              ? ref.watch(wealthBadgeProvider(level))
              : ref.watch(charmBadgeProvider(level)));

    return badgeAsync.when(
      data: (url) {
        if (url == null) {
          return Text(
            'Lv.$level',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        return SizedBox(
          width: 28,
          height: 18,
          child: CachedNetworkImage(
            imageUrl: url,
            height: 18,
            width: 28,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const SizedBox(width: 28, height: 18),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        );
      },
      loading: () => const SizedBox(width: 28, height: 18),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
