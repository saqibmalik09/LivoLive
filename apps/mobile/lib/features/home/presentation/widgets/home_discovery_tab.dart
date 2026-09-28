import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/providers/agency_ranking_provider.dart';
import 'package:sk_live/core/providers/discovery_rooms_for_grid_provider.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/providers/home_provider.dart';
import 'package:sk_live/core/providers/home_ranking_podium_config_provider.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart';
import 'package:sk_live/core/providers/pinned_party_rooms_provider.dart';
import 'package:sk_live/core/providers/podium_rank_frames_provider.dart';
import 'package:sk_live/core/providers/ranking_podium_preview_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/features/home/presentation/widgets/home_hot_cards_section.dart';
import 'package:sk_live/features/home/presentation/widgets/home_party_banner_slider.dart';
import 'package:sk_live/features/home/presentation/widgets/home_pinned_rooms_section.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ranking_podium_section.dart';

typedef HomeRoomGridBuilder =
    List<Widget> Function(
      List<Map<String, dynamic>> rooms,
      Map<String, int> giftTotals,
    );

class HomeDiscoveryTab extends ConsumerWidget {
  const HomeDiscoveryTab({
    super.key,
    required this.scrollController,
    required this.buildRoomGridWithMidBanner,
    required this.buildRoomsShimmer,
    this.onTopBannerTap,
  });

  final ScrollController scrollController;
  final HomeRoomGridBuilder buildRoomGridWithMidBanner;
  final Widget Function({int count}) buildRoomsShimmer;
  final void Function(Map<String, dynamic> banner)? onTopBannerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(discoveryRoomsPaginationProvider);
    final giftTotals = roomsState.giftTotals;
    final gridRooms = ref.watch(discoveryRoomsForGridProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bannersProvider('top'));
        ref.invalidate(bannersProvider('after_rooms'));
        ref.invalidate(homeTopBannerHeightProvider);
        ref.invalidate(rankingsProvider(('Room', 'Day')));
        ref.invalidate(homeRankingPodiumConfigProvider);
        ref.invalidate(homePodiumFramesProvider);
        ref.invalidate(podiumRankFramesProvider('Day'));
        ref.invalidate(rankingPodiumSlidesProvider);
        ref.invalidate(agencyRankingsProvider('Day'));
        ref.invalidate(pinnedPartyRoomsProvider);
        await ref.read(discoveryRoomsPaginationProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                HomePartyBannerSlider(
                  placement: 'top',
                  onBannerTap: onTopBannerTap,
                ),
                const HomePinnedRoomsSection(),
                const HomeRankingPodiumSection(),
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: const HomeRoomTop3CardsSection(),
                ),
                const SizedBox(height: 4),
              ]),
            ),
          ),
          if (roomsState.isLoading && roomsState.rooms.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverToBoxAdapter(child: buildRoomsShimmer(count: 6)),
            )
          else if (roomsState.error != null && roomsState.rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: shouldHideErrorFromUsers(roomsState.error)
                    ? const SizedBox.shrink()
                    : const Text(
                        'Something went wrong. Pull to refresh.',
                        style: TextStyle(color: Colors.red),
                      ),
              ),
            )
          else if (roomsState.rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.ghost,
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No active rooms found',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...buildRoomGridWithMidBanner(gridRooms, giftTotals),
          if (roomsState.isLoadingMore)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              sliver: SliverToBoxAdapter(child: buildRoomsShimmer(count: 2)),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: homeTabScrollBottomPadding(context),
            ),
          ),
        ],
      ),
    );
  }
}
