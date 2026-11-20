import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/home_ranking_podium_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/providers/ranking_podium_preview_provider.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/home_hot_cards_section.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

class HomeRankingPodiumSection extends ConsumerStatefulWidget {
  const HomeRankingPodiumSection({super.key, this.bannerTick});

  final Listenable? bannerTick;

  @override
  ConsumerState<HomeRankingPodiumSection> createState() =>
      _HomeRankingPodiumSectionState();
}

abstract final class RefLeaderboardLayout {
  static const double designWidth = 750;

  static const double cardWidth = 360;
  static const double cardHeight = 180;
  static const double pitch = 369;
  static const double bottomGap = 20;

  static const double titleTop = 9;
  static const double titleFont = 24;

  static const double top1Size = 109;
  static const double top1Top = 45;
  static const double sideSize = 92;
  static const double sideTop = 65;
  static const double sideOffset = 105;
}

class _HomeRankingPodiumSectionState
    extends ConsumerState<HomeRankingPodiumSection> {
  static const int _startRounds = 100;

  static const List<RankingPodiumSlideData> _loadingSlides = [
    RankingPodiumSlideData(category: RankingPodiumCategory.room, top3: []),
    RankingPodiumSlideData(category: RankingPodiumCategory.agency, top3: []),
    RankingPodiumSlideData(category: RankingPodiumCategory.charm, top3: []),
    RankingPodiumSlideData(category: RankingPodiumCategory.wealth, top3: []),
  ];

  PageController? _pageController;
  int _controllerSlideCount = 0;
  bool _precached = false;
  int _slideCount = 0;
  Timer? _ownTimer;
  Duration _ownInterval = const Duration(seconds: 4);
  DateTime _lastBannerMove = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.bannerTick?.addListener(_onBannerMoved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final asset in _RefCardStyle.allAssets) {
      unawaited(precacheImage(AssetImage(asset), context));
    }
  }

  @override
  void didUpdateWidget(covariant HomeRankingPodiumSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bannerTick != widget.bannerTick) {
      oldWidget.bannerTick?.removeListener(_onBannerMoved);
      widget.bannerTick?.addListener(_onBannerMoved);
    }
  }

  @override
  void dispose() {
    widget.bannerTick?.removeListener(_onBannerMoved);
    _ownTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  bool get _homeVisible =>
      mounted &&
      ref.read(bottomNavIndexProvider) == bottomNavIndexForKey('home') &&
      TickerMode.valuesOf(context).enabled;

  void _onBannerMoved() {
    _lastBannerMove = DateTime.now();
    _advance();
  }

  void _advance() {
    final controller = _pageController;
    if (_slideCount < 2 || controller == null || !controller.hasClients) {
      return;
    }
    if (!_homeVisible) return;
    final page = controller.page?.round() ?? controller.initialPage;
    controller.animateToPage(
      page + 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _ensureOwnTimer(HomeRankingPodiumConfig config) {
    final interval = Duration(
      milliseconds: config.slideIntervalMs.clamp(3000, 15000),
    );
    if (_ownTimer != null && interval == _ownInterval) return;
    _ownInterval = interval;
    _ownTimer?.cancel();
    _ownTimer = Timer.periodic(interval, (_) {
      final sinceBanner = DateTime.now().difference(_lastBannerMove);
      if (sinceBanner > interval + const Duration(seconds: 1)) _advance();
    });
  }

  void _openSlide(RankingPodiumCategory category) {
    final page = switch (category) {
      RankingPodiumCategory.wealth => 0,
      RankingPodiumCategory.charm => 1,
      RankingPodiumCategory.room => 2,
      RankingPodiumCategory.agency => 3,
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GiftCenterScreen(initialPage: page, initialPeriod: 'Day'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(homeRankingPodiumConfigProvider);
    final slidesAsync = ref.watch(rankingPodiumSlidesProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxWidth / RefLeaderboardLayout.designWidth;
        final height =
            (RefLeaderboardLayout.cardHeight + RefLeaderboardLayout.bottomGap) *
            s;
        Widget onSky(Widget child) => SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: RefSkyBackdrop(windowTop: RefTop3Layout.sectionHeight),
                ),
              ),
              child,
            ],
          ),
        );
        final empty = onSky(const SizedBox.shrink());

        Widget cards(List<RankingPodiumSlideData> slides) {
          _slideCount = slides.length;
          if (_pageController != null &&
              _controllerSlideCount != slides.length) {
            final old = _pageController!;
            WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
            _pageController = null;
          }
          _controllerSlideCount = slides.length;
          final controller = _pageController ??= PageController(
            viewportFraction:
                RefLeaderboardLayout.pitch / RefLeaderboardLayout.designWidth,
            initialPage: slides.length > 1 ? slides.length * _startRounds : 0,
          );

          return onSky(
            PageView.builder(
              key: ValueKey(slides.length),
              controller: controller,
              itemCount: slides.length > 1 ? null : 1,
              itemBuilder: (context, index) {
                final slide = slides[index % slides.length];
                return Align(
                  alignment: Alignment.topCenter,
                  child: _RefLeaderboardCard(
                    slide: slide,
                    scale: s,
                    onOpen: () => _openSlide(slide.category),
                    onTapEntry: _roomTap(slide),
                  ),
                );
              },
            ),
          );
        }

        return configAsync.when(
          loading: () => slidesAsync.hasError
              ? empty
              : cards(slidesAsync.valueOrNull ?? _loadingSlides),
          error: (_, _) => empty,
          data: (config) => slidesAsync.when(
            loading: () => cards(_loadingSlides),
            error: (_, _) => empty,
            data: (slides) {
              if (slides.isEmpty) return const SizedBox.shrink();
              _ensureOwnTimer(config);
              return cards(slides);
            },
          ),
        );
      },
    );
  }

  void Function(RankingPodiumEntry)? _roomTap(RankingPodiumSlideData slide) {
    if (slide.category != RankingPodiumCategory.room) return null;
    return (e) {
      unawaited(
        openRoomLive(context, {
          'id': e.id,
          'title': e.title,
          'image_url': e.avatarUrl,
        }),
      );
    };
  }
}

class _RefCardStyle {
  const _RefCardStyle({
    required this.card,
    required this.frames,
    required this.title,
    this.squarePhoto = false,
  });

  final String card;
  final Map<int, _RefFrame> frames;
  final String title;
  final bool squarePhoto;

  static const _dir = 'assets/design/home/leaderboard';

  static final Set<String> allAssets = {
    for (final category in RankingPodiumCategory.values) ...[
      of(category).card,
      for (final f in of(category).frames.values) f.asset,
    ],
  };

  static _RefCardStyle of(RankingPodiumCategory category) {
    switch (category) {
      case RankingPodiumCategory.wealth:
        return const _RefCardStyle(
          title: 'Wealth',
          card: '$_dir/card_wealth_gold.webp',
          frames: {
            1: _RefFrame(
              '$_dir/frame_wealth_set_top1_gold.webp',
              1,
              0.5,
              0.461,
              0.689,
            ),
            2: _RefFrame(
              '$_dir/frame_wealth_top2_silver.webp',
              1,
              0.5,
              0.46,
              0.68,
            ),
            3: _RefFrame(
              '$_dir/frame_wealth_top3_bronze.webp',
              1,
              0.487,
              0.46,
              0.68,
            ),
          },
        );
      case RankingPodiumCategory.charm:
        return const _RefCardStyle(
          title: 'Charm',
          card: '$_dir/card_charm_blue.webp',
          frames: {
            1: _RefFrame(
              '$_dir/frame_charm_heart.webp',
              1,
              0.494,
              0.456,
              0.683,
            ),
            2: _RefFrame(
              '$_dir/frame_charm_heart.webp',
              1,
              0.494,
              0.456,
              0.683,
            ),
            3: _RefFrame(
              '$_dir/frame_charm_heart.webp',
              1,
              0.494,
              0.456,
              0.683,
            ),
          },
        );
      case RankingPodiumCategory.room:
        return const _RefCardStyle(
          title: 'Room',
          card: '$_dir/card_room_red.webp',
          frames: {
            1: _RefFrame('$_dir/frame_room_top1.webp', 1, 0.5, 0.4635, 0.604),
            2: _RefFrame(
              '$_dir/frame_room_top2.webp',
              207 / 186,
              0.495,
              0.44,
              0.65,
            ),
            3: _RefFrame(
              '$_dir/frame_room_top3.webp',
              207 / 186,
              0.495,
              0.44,
              0.65,
            ),
          },
        );
      case RankingPodiumCategory.agency:
        return const _RefCardStyle(
          title: 'Agency',
          card: '$_dir/card_agency_green.webp',
          squarePhoto: true,
          frames: {
            1: _RefFrame(
              '$_dir/frame_agency_top1_square.webp',
              1,
              0.5,
              0.494,
              0.617,
            ),
            2: _RefFrame(
              '$_dir/frame_agency_top2_square.webp',
              1,
              0.5,
              0.5,
              0.64,
            ),
            3: _RefFrame(
              '$_dir/frame_agency_top3_square.webp',
              1,
              0.5,
              0.5,
              0.64,
            ),
          },
        );
    }
  }
}

class _RefFrame {
  const _RefFrame(this.asset, this.aspect, this.cx, this.cy, this.photo);

  final String asset;

  final double aspect;

  final double cx;
  final double cy;
  final double photo;
}

class _RefLeaderboardCard extends StatelessWidget {
  const _RefLeaderboardCard({
    required this.slide,
    required this.scale,
    required this.onOpen,
    this.onTapEntry,
  });

  final RankingPodiumSlideData slide;
  final double scale;
  final VoidCallback onOpen;
  final void Function(RankingPodiumEntry entry)? onTapEntry;

  @override
  Widget build(BuildContext context) {
    final style = _RefCardStyle.of(slide.category);
    final s = scale;
    const l = RefLeaderboardLayout.cardWidth;
    final entries = slide.top3;
    RankingPodiumEntry? entry(int rank) =>
        entries.length >= rank ? entries[rank - 1] : null;

    Widget frame(int rank, double size, double centreX, double top) {
      final f = style.frames[rank]!;
      return Positioned(
        left: (centreX - size / 2) * s,
        top: top * s,
        width: size * s,
        height: size * f.aspect * s,
        child: _RefRankFrame(
          frame: f,
          entry: entry(rank),
          square: style.squarePhoto,
          isRoom: slide.category == RankingPodiumCategory.room,
          onTapEntry: onTapEntry,
        ),
      );
    }

    return GestureDetector(
      onTap: onOpen,
      child: SizedBox(
        width: l * s,
        height: RefLeaderboardLayout.cardHeight * s,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                style.card,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: RefLeaderboardLayout.titleTop * s,
              child: Text(
                style.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: RefLeaderboardLayout.titleFont * s,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            frame(
              2,
              RefLeaderboardLayout.sideSize,
              l / 2 - RefLeaderboardLayout.sideOffset,
              RefLeaderboardLayout.sideTop,
            ),
            frame(
              3,
              RefLeaderboardLayout.sideSize,
              l / 2 + RefLeaderboardLayout.sideOffset,
              RefLeaderboardLayout.sideTop,
            ),
            frame(
              1,
              RefLeaderboardLayout.top1Size,
              l / 2,
              RefLeaderboardLayout.top1Top,
            ),
          ],
        ),
      ),
    );
  }
}

class _RefRankFrame extends StatelessWidget {
  const _RefRankFrame({
    required this.frame,
    required this.entry,
    required this.square,
    required this.isRoom,
    this.onTapEntry,
  });

  final _RefFrame frame;
  final RankingPodiumEntry? entry;
  final bool square;
  final bool isRoom;
  final void Function(RankingPodiumEntry entry)? onTapEntry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final photo = w * frame.photo;
        final url = entry?.avatarUrl;
        final radius = square ? photo * 0.08 : photo / 2;

        Widget photoBox = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ColoredBox(
            color: Colors.black26,
            child: url != null && url.isNotEmpty
                ? AppNetworkImage(
                    imageUrl: url,
                    transformWidth: (photo * 3).round(),
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Icon(
                      isRoom ? Icons.meeting_room : Icons.person,
                      color: Colors.white54,
                      size: photo * 0.4,
                    ),
                  )
                : Icon(
                    isRoom ? Icons.meeting_room : Icons.person,
                    color: Colors.white24,
                    size: photo * 0.45,
                  ),
          ),
        );
        final tapped = entry;
        if (tapped != null && onTapEntry != null) {
          photoBox = GestureDetector(
            onTap: () => onTapEntry!(tapped),
            child: photoBox,
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: w * frame.cx - photo / 2,
              top: h * frame.cy - photo / 2,
              width: photo,
              height: photo,
              child: photoBox,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  frame.asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
