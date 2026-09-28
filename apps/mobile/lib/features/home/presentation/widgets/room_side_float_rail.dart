import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/providers/room_side_float_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';
import 'package:sk_live/features/home/presentation/pages/open_party_event.dart';
import 'package:sk_live/features/home/presentation/pages/sk_party/sk_party_assets.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';
import 'package:sk_live/features/home/presentation/widgets/room_reward/room_reward_float_button.dart';
import 'package:sk_live/features/home/presentation/widgets/weekly_room_reward/weekly_room_reward_float_button.dart';

class RoomSideFloatRail extends ConsumerWidget {
  const RoomSideFloatRail({
    super.key,
    required this.roomId,
    required this.activeGames,
    required this.onGameTap,
    this.size = 56,
  });

  final String roomId;
  final List<Map<String, dynamic>> activeGames;
  final void Function(Map<String, dynamic> game) onGameTap;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floatAsync = ref.watch(roomSideFloatItemsProvider);
    final eventsAsync = ref.watch(partyEventsProvider);

    final floatItems = floatAsync.valueOrNull ?? const <RoomSideFloatItem>[];
    final partyEvents = eventsAsync.valueOrNull ?? const <PartyEvent>[];

    final adminEvents = floatItems
        .where((e) => e.kind == RoomSideFloatKind.event)
        .toList();
    final adminGames = floatItems
        .where((e) => e.kind == RoomSideFloatKind.game)
        .toList();

    final eventSlides = _buildEventSlides(
      adminItems: adminEvents,
      partyEvents: partyEvents,
    );
    final gameSlides = _buildGameSlides(
      adminItems: adminGames,
      activeGames: activeGames,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RewardFloatCycle(roomId: roomId, size: size),
        if (gameSlides.isNotEmpty) ...[
          const SizedBox(height: 8),
          _FloatCarousel(
            size: size,
            slides: gameSlides,
            onTap: (slide) {
              final game = _resolveGame(slide, activeGames);
              if (game != null) onGameTap(game);
            },
          ),
        ],
        if (eventSlides.isNotEmpty) ...[
          const SizedBox(height: 8),
          _FloatCarousel(
            size: size,
            slides: eventSlides,
            onTap: (slide) {
              final event = _resolveEvent(slide, partyEvents);
              if (event != null) openPartyEvent(context, event);
            },
          ),
        ],
      ],
    );
  }

  List<_FloatSlide> _buildEventSlides({
    required List<RoomSideFloatItem> adminItems,
    required List<PartyEvent> partyEvents,
  }) {
    if (adminItems.isNotEmpty) {
      return adminItems
          .map((item) {
            PartyEvent? linked;
            if (item.partyEventId != null) {
              for (final e in partyEvents) {
                if (e.id == item.partyEventId) {
                  linked = e;
                  break;
                }
              }
            }
            return _FloatSlide(
              keyId: item.id,
              title: item.title.isNotEmpty
                  ? item.title
                  : (linked?.title ?? 'Event'),
              networkUrl: item.imageUrl.isNotEmpty
                  ? item.imageUrl
                  : (linked?.versionedBannerUrl ?? ''),
              assetPath: linked == null
                  ? null
                  : _bundledBannerFor(linked.eventKind),
              partyEventId: item.partyEventId ?? linked?.id,
              gameSlug: null,
            );
          })
          .where((s) => s.networkUrl.isNotEmpty || s.assetPath != null)
          .toList();
    }

    return partyEvents
        .map((e) {
          final asset = _bundledBannerFor(e.eventKind);
          return _FloatSlide(
            keyId: e.id,
            title: e.title,
            networkUrl: e.bannerUrl.isNotEmpty ? e.versionedBannerUrl : '',
            assetPath: asset,
            partyEventId: e.id,
            gameSlug: null,
          );
        })
        .where((s) => s.networkUrl.isNotEmpty || s.assetPath != null)
        .toList();
  }

  List<_FloatSlide> _buildGameSlides({
    required List<RoomSideFloatItem> adminItems,
    required List<Map<String, dynamic>> activeGames,
  }) {
    if (adminItems.isNotEmpty) {
      return adminItems
          .map((item) {
            Map<String, dynamic>? linked;
            if (item.gameSlug != null) {
              for (final g in activeGames) {
                if (g['slug']?.toString() == item.gameSlug) {
                  linked = g;
                  break;
                }
              }
            }
            final icon = item.imageUrl.isNotEmpty
                ? item.imageUrl
                : (linked?['icon_url']?.toString() ?? '');
            return _FloatSlide(
              keyId: item.id,
              title: item.title.isNotEmpty
                  ? item.title
                  : (linked?['name']?.toString() ?? 'Game'),
              networkUrl: icon,
              assetPath: null,
              partyEventId: null,
              gameSlug: item.gameSlug ?? linked?['slug']?.toString(),
            );
          })
          .where((s) => s.networkUrl.isNotEmpty)
          .toList();
    }

    return activeGames
        .map((g) {
          final icon = g['icon_url']?.toString() ?? '';
          return _FloatSlide(
            keyId: g['slug']?.toString() ?? g['id']?.toString() ?? icon,
            title: g['name']?.toString() ?? 'Game',
            networkUrl: icon,
            assetPath: null,
            partyEventId: null,
            gameSlug: g['slug']?.toString(),
          );
        })
        .where((s) => s.networkUrl.isNotEmpty)
        .toList();
  }

  String? _bundledBannerFor(PartyEventKind kind) {
    return switch (kind) {
      PartyEventKind.weeklyStarNative => WeeklyStarAssets.banner,
      PartyEventKind.gameStarNative => GameStarAssets.banner,
      PartyEventKind.skHostNative => SkPartyAssets.banner,
      _ => null,
    };
  }

  PartyEvent? _resolveEvent(_FloatSlide slide, List<PartyEvent> events) {
    if (slide.partyEventId == null) return null;
    for (final e in events) {
      if (e.id == slide.partyEventId) return e;
    }
    return null;
  }

  Map<String, dynamic>? _resolveGame(
    _FloatSlide slide,
    List<Map<String, dynamic>> games,
  ) {
    if (slide.gameSlug == null) return null;
    for (final g in games) {
      if (g['slug']?.toString() == slide.gameSlug) return g;
    }
    return null;
  }
}

class _FloatSlide {
  const _FloatSlide({
    required this.keyId,
    required this.title,
    required this.networkUrl,
    required this.assetPath,
    required this.partyEventId,
    required this.gameSlug,
  });

  final String keyId;
  final String title;
  final String networkUrl;
  final String? assetPath;
  final String? partyEventId;
  final String? gameSlug;
}

class _FloatCarousel extends StatefulWidget {
  const _FloatCarousel({
    required this.size,
    required this.slides,
    required this.onTap,
  });

  final double size;
  final List<_FloatSlide> slides;
  final void Function(_FloatSlide slide) onTap;

  @override
  State<_FloatCarousel> createState() => _FloatCarouselState();
}

class _FloatCarouselState extends State<_FloatCarousel> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _FloatCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.slides.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.slides.isEmpty) return;
      setState(() {
        _index = (_index + 1) % widget.slides.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    final slide = widget.slides[_index.clamp(0, widget.slides.length - 1)];

    return GestureDetector(
      onTap: () => widget.onTap(slide),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Container(
          key: ValueKey('${slide.keyId}_$_index'),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildImage(slide),
        ),
      ),
    );
  }

  Widget _buildImage(_FloatSlide slide) {
    if (slide.networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: slide.networkUrl,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        fadeInDuration: Duration.zero,
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) {
          if (slide.assetPath != null) {
            return Image.asset(
              slide.assetPath!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            );
          }
          return _placeholder();
        },
      );
    }
    if (slide.assetPath != null) {
      return Image.asset(
        slide.assetPath!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: const Color(0xFF2A2A3A),
      child: Icon(Icons.image, color: Colors.white24, size: widget.size * 0.4),
    );
  }
}

class _RewardFloatCycle extends StatefulWidget {
  const _RewardFloatCycle({required this.roomId, required this.size});

  final String roomId;
  final double size;

  @override
  State<_RewardFloatCycle> createState() => _RewardFloatCycleState();
}

class _RewardFloatCycleState extends State<_RewardFloatCycle> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % 2);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey('reward_float_$_index'),
        child: _index == 0
            ? RoomRewardFloatButton(roomId: widget.roomId, size: widget.size)
            : WeeklyRoomRewardFloatButton(
                roomId: widget.roomId,
                size: widget.size,
              ),
      ),
    );
  }
}
