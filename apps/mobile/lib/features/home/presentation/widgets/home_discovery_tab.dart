import 'dart:math' as math;

import 'package:flutter/gestures.dart' show Drag;
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
import 'package:sk_live/core/providers/rooms_daily_gift_totals_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/features/home/presentation/widgets/home_hot_cards_section.dart';
import 'package:sk_live/features/home/presentation/widgets/home_party_banner_slider.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ranking_podium_section.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_chips_row.dart';

typedef HomeRoomGridBuilder =
    List<Widget> Function(
      List<Map<String, dynamic>> rooms,
      Map<String, int> giftTotals,
    );

class HomeDiscoveryTab extends ConsumerStatefulWidget {
  const HomeDiscoveryTab({
    super.key,
    required this.scrollController,
    required this.buildRoomGridWithMidBanner,
    required this.buildRoomsShimmer,
    this.onTopBannerTap,
    this.chipsRow,
  });

  final ScrollController scrollController;
  final HomeRoomGridBuilder buildRoomGridWithMidBanner;
  final Widget Function({int count}) buildRoomsShimmer;
  final void Function(Map<String, dynamic> banner)? onTopBannerTap;

  final Widget? chipsRow;

  @override
  ConsumerState<HomeDiscoveryTab> createState() => _HomeDiscoveryTabState();
}

class _HomeDiscoveryTabState extends ConsumerState<HomeDiscoveryTab> {
  final ValueNotifier<int> _bannerTick = ValueNotifier<int>(0);

  // Whether the Top3/banner/podium header is still within (or close to) the
  // viewport. Driven by the scroll controller directly so toggling it never
  // forces a rebuild of the whole discovery tab: only the AnimatedBuilders
  // that read it below rebuild, and they keep the heavy Top3/podium subtrees
  // as a stable `child` so those subtrees skip rebuilding entirely.
  final ValueNotifier<bool> _topVisible = ValueNotifier<bool>(true);

  double _chipsSlotOffset = 0;

  // Published separately from the field above so a slot change repaints the
  // chips overlay and the clip without rebuilding the whole tab. See
  // _noteChipsSlot.
  final ValueNotifier<double> _chipsSlotTick = ValueNotifier<double>(0);

  // Drives the two AnimatedBuilders that position the chips: the scroll
  // controller for the common case, the tick for when the header above the
  // chips changes height while the list is standing still.
  Listenable? _chipsListenable;

  // Scroll extent preceding the chips slot == height of banner+Top3+podium.
  double _topSectionExtent = 0;

  double? _globalTop;
  Drag? _chipsDrag;

  static const double _refChipsPinnedTop = 200;

  // Small buffer so the header doesn't flicker on/off right at the boundary.
  static const double _topVisibleSlack = 80;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleHeaderScroll);
    _chipsListenable = Listenable.merge([
      widget.scrollController,
      _chipsSlotTick,
    ]);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleHeaderScroll);
    _bannerTick.dispose();
    _topVisible.dispose();
    _chipsSlotTick.dispose();
    super.dispose();
  }

  void _handleHeaderScroll() {
    final c = widget.scrollController;
    final offset = c.hasClients ? c.offset : 0.0;
    // ValueNotifier only notifies listeners when the value actually changes,
    // so this is safe to call on every scroll frame.
    _topVisible.value = offset < _topSectionExtent + _topVisibleSlack;
  }

  void _onTopBannerPageChanged(int _) => _bannerTick.value++;

  void _noteTopSectionExtent(double offset) {
    if ((offset - _topSectionExtent).abs() < 0.5) return;
    _topSectionExtent = offset;
    // Not driven by setState: only the scroll listener above reads this
    // field, so recording it does not need to repaint anything by itself.
  }

  void _noteChipsSlot(double offset) {
    if ((offset - _chipsSlotOffset).abs() < 0.5) return;
    _chipsSlotOffset = offset;
    // This used to setState the whole tab, from a sliver layout callback that
    // fires while the list is scrolling past the header. Each one re-read the
    // pagination provider, rebuilt the listed-id set, re-sorted the gift-total
    // key and handed the grid brand-new delegates — mid-fling. That is the
    // half-second catch that made a swipe not take.
    //
    // Only the chips overlay and the clip read this, and both already rebuild
    // per scroll frame, so publishing it through a notifier is enough.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chipsSlotTick.value = _chipsSlotOffset;
    });
  }

  void _noteGlobalTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero).dy;
      if (_globalTop == null || (top - _globalTop!).abs() > 0.5) {
        setState(() => _globalTop = top);
      }
    });
  }

  void _chipsDragStart(DragStartDetails d) {
    final c = widget.scrollController;
    if (!c.hasClients) return;
    _chipsDrag = c.position.drag(d, () => _chipsDrag = null);
  }

  double _scale(BuildContext context) =>
      MediaQuery.sizeOf(context).width / HomePartyBannerSlider.refDesignWidth;

  @override
  Widget build(BuildContext context) {
    final scrollController = widget.scrollController;
    final buildRoomGridWithMidBanner = widget.buildRoomGridWithMidBanner;
    final buildRoomsShimmer = widget.buildRoomsShimmer;
    final onTopBannerTap = widget.onTopBannerTap;
    final roomsState = ref.watch(discoveryRoomsPaginationProvider);
    final gridRooms = ref.watch(discoveryRoomsForGridProvider);
    final listedIds = {
      for (final r in roomsState.rooms) r['id']?.toString() ?? '',
    };
    final extraKey = roomsDailyGiftTotalsKey(
      gridRooms.where((r) => !listedIds.contains(r['id']?.toString() ?? '')),
    );
    final extraTotals = extraKey.isEmpty
        ? const <String, int>{}
        : ref.watch(roomsDailyGiftTotalsProvider(extraKey)).valueOrNull ??
              const <String, int>{};
    final giftTotals = extraTotals.isEmpty
        ? roomsState.giftTotals
        : <String, int>{...extraTotals, ...roomsState.giftTotals};

    final chips = widget.chipsRow;
    final s = _scale(context);
    final chipsHeight = HomeRefChipsRow.rowHeight(s);

    final list = RefreshIndicator(
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
        // About one screen of cards stay built, so a short scroll back reuses
        // decoded covers. 80 disposed them immediately; an unbounded extent
        // decodes the whole list during a fling.
        cacheExtent: 600,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: RefSkyBackdrop(windowBottom: 0)),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    HomePartyBannerSlider.refTopSide * _scale(context),
                    4,
                    HomePartyBannerSlider.refTopSide * _scale(context),
                    0,
                  ),
                  child: AnimatedBuilder(
                    animation: _topVisible,
                    builder: (context, _) => HomePartyBannerSlider(
                      placement: 'top',
                      onBannerTap: onTopBannerTap,
                      onPageChanged: _onTopBannerPageChanged,
                      active: _topVisible.value,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _topVisible,
              builder: (context, child) =>
                  TickerMode(enabled: _topVisible.value, child: child!),
              child: const HomeRoomTop3CardsSection(),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _topVisible,
              builder: (context, child) =>
                  TickerMode(enabled: _topVisible.value, child: child!),
              child: HomeRankingPodiumSection(bannerTick: _bannerTick),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              _noteTopSectionExtent(constraints.precedingScrollExtent);
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),
          if (chips != null)
            SliverLayoutBuilder(
              builder: (context, constraints) {
                _noteChipsSlot(constraints.precedingScrollExtent);
                return SliverToBoxAdapter(child: SizedBox(height: chipsHeight));
              },
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

    if (chips == null) return list;
    _noteGlobalTop();
    final pinnedTop = math.max(
      0.0,
      _refChipsPinnedTop * s - HomeRefChipsRow.chipTop(s) - (_globalTop ?? 0),
    );
    double chipsTop() {
      final c = widget.scrollController;
      final offset = c.hasClients ? c.offset : 0.0;
      return math.max(pinnedTop, _chipsSlotOffset - offset);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _chipsListenable!,
          builder: (context, child) {
            final top = chipsTop();
            final pinned = top <= pinnedTop + 0.5;
            // RepaintBoundary isolates the scroll content's own layer so the
            // per-frame clip-rect change doesn't force the chips overlay (a
            // sibling in this Stack) to repaint, and vice versa.
            return RepaintBoundary(
              child: ClipRect(
                clipper: _TopCut(pinned ? top + chipsHeight : 0),
                child: child,
              ),
            );
          },
          child: list,
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _chipsListenable!,
            builder: (context, child) => Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  top: chipsTop(),
                  left: 0,
                  right: 0,
                  height: chipsHeight,
                  child: child!,
                ),
              ],
            ),
            child: RepaintBoundary(
              child: GestureDetector(
                onVerticalDragStart: _chipsDragStart,
                onVerticalDragUpdate: (d) => _chipsDrag?.update(d),
                onVerticalDragEnd: (d) => _chipsDrag?.end(d),
                onVerticalDragCancel: () => _chipsDrag?.cancel(),
                child: chips,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopCut extends CustomClipper<Rect> {
  const _TopCut(this.cut);

  final double cut;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, cut.clamp(0, size.height), size.width, size.height);

  @override
  bool shouldReclip(_TopCut oldClipper) => oldClipper.cut != cut;
}
