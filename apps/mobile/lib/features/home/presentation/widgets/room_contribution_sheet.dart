import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/room_contribution_provider.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/number_formatter.dart';

class RoomContributionSheet extends ConsumerStatefulWidget {
  const RoomContributionSheet({super.key, required this.roomId});

  final String roomId;

  static const _sheetBg = 'assets/room/room_contribution_sheet_bg.webp';
  static const _podiumBg = 'assets/room/room_contribution_podium.webp';

  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required String roomId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomContributionSheet(roomId: roomId),
    );
  }

  @override
  ConsumerState<RoomContributionSheet> createState() =>
      _RoomContributionSheetState();
}

class _RoomContributionSheetState extends ConsumerState<RoomContributionSheet> {
  int _selectedPeriodIndex = 0;

  static const _periods = ['Daily', 'Weekly'];

  String get _period => _periods[_selectedPeriodIndex];

  String _frameForRank(int rank) {
    switch (rank) {
      case 1:
        return 'assets/ranking/rank_1_frame.webp';
      case 2:
        return 'assets/ranking/rank_2_frame.webp';
      default:
        return 'assets/ranking/rank_3_frame.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankingsAsync = ref.watch(
      roomContributionRankingsProvider((widget.roomId, _period)),
    );
    final maxH = MediaQuery.of(context).size.height * 0.72;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: maxH + bottomInset,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            RoomContributionSheet._sheetBg,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A1A0F), Color(0xFF1A1208)],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          Column(
            children: [
              _buildHeader(rankingsAsync),
              _buildPeriodTabs(),
              Expanded(
                child: rankingsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (e, st) => Center(
                    child: Text(
                      'Failed to load contributions',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  data: (rankings) {
                    if (rankings.isEmpty) {
                      return Center(
                        child: Text(
                          'No contributions yet.\nSend gifts to appear on the board!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
                      child: Column(
                        children: [
                          _buildPodiumSection(rankings),
                          const SizedBox(height: 8),
                          ...rankings
                              .asMap()
                              .entries
                              .where((e) => e.key >= 3)
                              .map((e) => _buildRow(e.value, e.key + 1)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumSection(List<GiftRankingModel> rankings) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Image.asset(
              RoomContributionSheet._podiumBg,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(height: 120),
            ),
          ),
          if (rankings.length > 1)
            Positioned(
              left: 8,
              bottom: 80,
              child: _buildPodiumUser(rankings[1], 2, 68),
            ),
          if (rankings.length > 2)
            Positioned(
              right: 8,
              bottom: 74,
              child: _buildPodiumUser(rankings[2], 3, 64),
            ),
          if (rankings.isNotEmpty)
            Positioned(
              bottom: 100,
              child: _buildPodiumUser(rankings[0], 1, 88),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<GiftRankingModel>> rankingsAsync) {
    final total = rankingsAsync.maybeWhen(
      data: roomContributionTotal,
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const Expanded(
            child: Text(
              'Room Contribution Title',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildCoinPill(total, compact: false),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF3D2A1A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: List.generate(_periods.length, (i) {
            final active = _selectedPeriodIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriodIndex = i),
                child: Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [Color(0xFFE5C78F), Color(0xFFD4A853)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _periods[i],
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF2A1A0F)
                          : Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCoinPill(int amount, {required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3D2A1A).withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.coin, color: AppColors.gold, size: compact ? 9 : 14),
          SizedBox(width: compact ? 2 : 4),
          Text(
            NumberFormatter.format(amount),
            style: TextStyle(
              color: AppColors.gold,
              fontSize: compact ? 8 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumUser(GiftRankingModel user, int rank, double frameSize) {
    final avatarSize = frameSize * (rank == 1 ? 0.55 : 0.62);
    return GestureDetector(
      onTap: () => NavigationUtils.navigateToProfile(context, ref, user.userId),
      child: SizedBox(
        width: frameSize + 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black26,
                  ),
                  child: ClipOval(
                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.white54,
                            size: 20,
                          ),
                  ),
                ),
                Image.asset(
                  _frameForRank(rank),
                  width: frameSize,
                  height: frameSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLevelBadge(
                  user.charmLevel ?? user.userLevel ?? 1,
                  'charm',
                ),
                const SizedBox(width: 3),
                _buildLevelBadge(user.wealthLevel ?? 1, 'wealth'),
              ],
            ),
            const SizedBox(height: 4),
            _buildCoinPill(user.score, compact: false),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(GiftRankingModel user, int displayRank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3D2A1A).withValues(alpha: 0.75),
            const Color(0xFF2A1A0F).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$displayRank',
              style: TextStyle(
                color: displayRank <= 3 ? AppColors.gold : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                NavigationUtils.navigateToProfile(context, ref, user.userId),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.black26,
              backgroundImage:
                  user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _buildLevelBadge(
                      user.charmLevel ?? user.userLevel ?? 1,
                      'charm',
                    ),
                    const SizedBox(width: 4),
                    _buildLevelBadge(user.wealthLevel ?? 1, 'wealth'),
                  ],
                ),
              ],
            ),
          ),
          _buildCoinPill(user.score, compact: false),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(int level, String category) {
    final badgeAsync = category == 'wealth'
        ? ref.watch(wealthBadgeProvider(level))
        : ref.watch(charmBadgeProvider(level));

    return badgeAsync.when(
      data: (url) {
        if (url == null) {
          return Text(
            'Lv.$level',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        return CachedNetworkImage(
          imageUrl: url,
          height: 16,
          fit: BoxFit.contain,
          placeholder: (_, _) => const SizedBox(width: 16, height: 16),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox(width: 16, height: 16),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class RoomContributionStrip extends ConsumerWidget {
  const RoomContributionStrip({
    super.key,
    required this.roomId,
    required this.onTap,
  });

  final String roomId;
  final VoidCallback onTap;

  static const _coinAsset = 'assets/rewards/lucky-bag/coin-1.webp';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(
      roomContributionRankingsProvider((roomId, 'Daily')),
    );
    final total = rankingsAsync.maybeWhen(
      data: roomContributionTotal,
      orElse: () => 0,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minWidth: 38, maxWidth: 58),
        padding: const EdgeInsets.fromLTRB(4, 1, 5, 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF3C4).withValues(alpha: 0.22),
              Colors.black.withValues(alpha: 0.62),
              const Color(0xFF3A2A08).withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.55),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _coinAsset,
              width: 12,
              height: 12,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const Icon(Iconsax.coin, color: AppColors.gold, size: 10),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                NumberFormatter.format(total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFE08A),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
