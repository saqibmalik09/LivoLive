import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/home_ranking_podium_config_provider.dart';
import 'package:sk_live/core/providers/podium_rank_frames_provider.dart';
import 'package:sk_live/core/providers/ranking_podium_preview_provider.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/features/home/presentation/widgets/ranking_podium_top3.dart';

class HomeRankingPodiumSection extends ConsumerStatefulWidget {
  const HomeRankingPodiumSection({super.key});

  @override
  ConsumerState<HomeRankingPodiumSection> createState() =>
      _HomeRankingPodiumSectionState();
}

class _HomeRankingPodiumSectionState
    extends ConsumerState<HomeRankingPodiumSection> {
  static const _leftAsset = 'assets/home/banners/container_1.webp';
  static const _midAsset = 'assets/home/banners/container_2.webp';
  static const _rightAsset = 'assets/home/banners/container_3.webp';

  Timer? _midFlipTimer;
  int _midFlipIndex = 0;
  String? _scheduledForVersion;

  @override
  void dispose() {
    _midFlipTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidFlip(HomeRankingPodiumConfig config, bool enabled) {
    if (_scheduledForVersion == config.cacheVersion) return;
    _scheduledForVersion = config.cacheVersion;
    _midFlipTimer?.cancel();
    if (!enabled) return;

    final interval = Duration(
      milliseconds: config.slideIntervalMs.clamp(3000, 15000),
    );
    _midFlipTimer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() => _midFlipIndex = 1 - _midFlipIndex);
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

  RankingPodiumSlideData? _slideFor(
    List<RankingPodiumSlideData> slides,
    RankingPodiumCategory category,
  ) {
    for (final s in slides) {
      if (s.category == category) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(homeRankingPodiumConfigProvider);
    final slidesAsync = ref.watch(rankingPodiumSlidesProvider);
    final podiumFramesAsync = ref.watch(homePodiumFramesProvider);

    const rowHeight = 118.0;

    return configAsync.when(
      loading: () => const SizedBox(height: rowHeight),
      error: (_, _) => const SizedBox(height: rowHeight),
      data: (config) {
        return slidesAsync.when(
          loading: () => const SizedBox(height: rowHeight),
          error: (_, _) => const SizedBox(height: rowHeight),
          data: (slides) {
            if (slides.isEmpty) return const SizedBox.shrink();

            RankingPodiumSlideData pick(
              RankingPodiumCategory cat,
              RankingPodiumSlideData fallback,
            ) => _slideFor(slides, cat) ?? fallback;

            final left = pick(RankingPodiumCategory.room, slides.first);
            RankingPodiumSlideData? otherThan(RankingPodiumCategory a) {
              for (final s in slides) {
                if (s.category != a) return s;
              }
              return null;
            }

            RankingPodiumSlideData? otherThanTwo(
              RankingPodiumCategory a,
              RankingPodiumCategory b,
            ) {
              for (final s in slides) {
                if (s.category != a && s.category != b) return s;
              }
              return null;
            }

            final right =
                _slideFor(slides, RankingPodiumCategory.charm) ??
                otherThan(left.category) ??
                left;
            final midA =
                _slideFor(slides, RankingPodiumCategory.agency) ??
                otherThanTwo(left.category, right.category);
            final midB = _slideFor(slides, RankingPodiumCategory.wealth);
            final midSlides = <RankingPodiumSlideData>[
              if (midA != null) midA,
              if (midB != null && midB.category != midA?.category) midB,
            ];
            if (midSlides.isEmpty) midSlides.add(left);

            _scheduleMidFlip(config, midSlides.length > 1);
            final mid = midSlides[_midFlipIndex % midSlides.length];
            final framesBundle =
                podiumFramesAsync.valueOrNull ?? const HomePodiumFramesBundle();

            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              child: Transform.translate(
                offset: const Offset(0, -10),
                child: SizedBox(
                  height: rowHeight - 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _RankingContainerCard(
                          asset: _leftAsset,
                          slide: left,
                          frames: framesBundle.forSlide(left.category),
                          onOpen: () => _openSlide(left.category),
                          onTapEntry: _roomTap(left),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _RankingContainerCard(
                          asset: _midAsset,
                          slide: mid,
                          frames: framesBundle.forSlide(mid.category),
                          framesOffsetY: 0,
                          animateKey: ValueKey(
                            'mid-${mid.category.name}-$_midFlipIndex',
                          ),
                          onOpen: () => _openSlide(mid.category),
                          onTapEntry: _roomTap(mid),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _RankingContainerCard(
                          asset: _rightAsset,
                          slide: right,
                          frames: framesBundle.forSlide(right.category),
                          imageScale: 0.92,
                          onOpen: () => _openSlide(right.category),
                          onTapEntry: _roomTap(right),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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

class _RankingContainerCard extends StatelessWidget {
  const _RankingContainerCard({
    required this.asset,
    required this.slide,
    required this.frames,
    required this.onOpen,
    this.onTapEntry,
    this.animateKey,
    this.framesOffsetY = 0,
    this.imageScale = 1.0,
  });

  final String asset;
  final RankingPodiumSlideData slide;
  final Map<int, PodiumRankFrame> frames;
  final VoidCallback onOpen;
  final void Function(RankingPodiumEntry entry)? onTapEntry;
  final Key? animateKey;
  final double framesOffsetY;
  final double imageScale;

  String get _title {
    return switch (slide.category) {
      RankingPodiumCategory.room => 'Room',
      RankingPodiumCategory.agency => 'Agency',
      RankingPodiumCategory.charm => 'Charm',
      RankingPodiumCategory.wealth => 'Wealth',
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: imageScale,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12),
          ),
        ),
        Positioned(
          top: 18 + (1 - imageScale) * 10,
          left: 10,
          right: 10,
          child: Text(
            _title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 4 + (1 - imageScale) * 8,
          right: 4 + (1 - imageScale) * 8,
          bottom: 16 - framesOffsetY + (1 - imageScale) * 8,
          top: 22 + framesOffsetY + (1 - imageScale) * 6,
          child: Align(
            alignment: Alignment.topCenter,
            child: RankingPodiumTop3(
              entries: slide.top3,
              framesByRank: frames,
              rank1Top: 0,
              compact: true,
              isRoom: slide.category == RankingPodiumCategory.room,
              onTapEntry: onTapEntry,
            ),
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: onOpen,
      child: animateKey == null
          ? content
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(key: animateKey, child: content),
            ),
    );
  }
}
