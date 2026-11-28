import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sk_live/core/util/app_image_cache.dart';
import 'package:sk_live/core/util/gift_show_duration.dart';
import 'package:sk_live/core/util/gift_video_cache.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/util/svga_cache.dart';
import 'package:sk_live/core/widgets/gift_video_player.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class GiftFlightRequest {
  final String? dedupeKey;
  final String senderId;
  final List<String> targetIds;
  final String imageUrl;
  final int quantity;
  final bool isFullScreen;
  final String svgaUrl;
  final Offset Function(String userId) resolveOffset;

  /// Pop the gift in the middle of the screen and hold it there before it
  /// flies to the receivers. A gift sent quickly after the previous one from
  /// the same [comboKey] skips the hold and flies straight away.
  final bool holdAtCenter;

  /// Who is sending, for telling a fast combo apart from a fresh gift.
  /// [senderId] is only the spawn point and is shared by every sender.
  final String comboKey;

  const GiftFlightRequest({
    this.dedupeKey,
    required this.senderId,
    required this.targetIds,
    required this.imageUrl,
    required this.quantity,
    this.isFullScreen = false,
    this.svgaUrl = '',
    required this.resolveOffset,
    this.holdAtCenter = false,
    this.comboKey = '',
  });
}

class GiftFlightController {
  GiftFlightManagerState? _state;

  void _attach(GiftFlightManagerState state) => _state = state;

  void _detach(GiftFlightManagerState state) {
    if (_state == state) _state = null;
  }

  void enqueue(GiftFlightRequest request) => _state?.enqueue(request);

  bool hasPlayed(String dedupeKey) => _state?.hasPlayed(dedupeKey) ?? false;

  void markPlayed(String dedupeKey) => _state?.markPlayed(dedupeKey);

  void clearAll() => _state?.clearAll();

  int get activeFlightCount => _state?.activeFlightCount ?? 0;
}

class GiftFlightManager extends StatefulWidget {
  final GiftFlightController controller;
  final Widget child;
  final void Function(String svgaUrl)? onFullScreenSvga;

  const GiftFlightManager({
    super.key,
    required this.controller,
    required this.child,
    this.onFullScreenSvga,
  });

  @override
  State<GiftFlightManager> createState() => GiftFlightManagerState();
}

class GiftFlightManagerState extends State<GiftFlightManager>
    with TickerProviderStateMixin {
  static const double _iconSize = 64.0;
  static const double _iconHalf = _iconSize / 2;
  static int _chainSeq = 0;

  /// How many waves of a single combo are animated.
  ///
  /// A quantity of 66 used to animate 66 waves, and a wave only started once
  /// every icon in the previous one had landed. At roughly half a second each
  /// that is half a minute of icons trickling in while the banner already said
  /// 66 — and with several senders at once the drip never caught up. The
  /// quantity is carried by the gift banner; the flights only need to read as
  /// a burst, so they are capped and overlapped.
  static const int _maxAnimatedWaves = 12;

  /// Gap between waves of the same combo. Waves overlap rather than queue, so
  /// any quantity lands inside about a second and a half.
  static const int _waveStaggerMs = 90;

  /// Ceiling on icons in flight from everybody at once. Past this the frame
  /// cost shows up on a cheap phone, and nobody can tell forty icons from two
  /// hundred — especially with 100k-room gift storms.
  static const int _maxActiveFlights = 40;

  /// Soft cap on cached gift icon providers for a long room session.
  static const int _maxImageCacheEntries = 32;

  /// Centre-hold timeline: pop in, sit in the middle, then fly to the seat.
  static const int _heroPopMs = 240;
  static const int _heroHoldMs = 2600;
  static const int _heroFlyMs = 650;
  static const double _heroScale = 1.9;

  /// Longest a first-time gift waits in the centre for its SVGA before
  /// holding the icon instead.
  static const Duration _heroSvgaWait = Duration(seconds: 5);

  /// Minimum time an SVGA that arrived late stays on screen before flying.
  static const int _heroLateSvgaShowMs = 1500;

  /// Hold for a first-send gift that a newer gift asked to release while its
  /// SVGA was still downloading: long enough to see the animation.
  static const int _heroReleasedHoldMs = 1400;

  /// A gift from the same sender inside this gap is a combo: it skips the
  /// hold so fast tapping keeps flying fast.
  static const int _comboGapMs = 1200;

  /// A new sender's gift takes the centre, but the one already there keeps
  /// it for at least this long first.
  static const int _heroMinHoldMs = 900;

  /// Past this many icons on screen a storm is going on; everything flies
  /// direct instead of queueing up in the middle.
  static const int _heroMaxActive = 16;

  final Map<String, List<_RunnableBatch>> _chainQueues = {};
  final Map<String, Timer> _chainTimers = {};
  final List<_ActiveSingle> _activeSingles = [];
  final Set<String> _playedDedupeKeys = {};
  final Map<String, ImageProvider> _imageCache = {};
  final Map<String, int> _lastGiftAtMs = {};
  bool _rebuildScheduled = false;

  int get activeFlightCount => _activeSingles.length;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    for (final timer in _chainTimers.values) {
      timer.cancel();
    }
    _chainTimers.clear();
    for (final f in _activeSingles) {
      f.releaseTimer?.cancel();
      f.controller.dispose();
    }
    _activeSingles.clear();
    _chainQueues.clear();
    super.dispose();
  }

  bool hasPlayed(String dedupeKey) => _playedDedupeKeys.contains(dedupeKey);

  void markPlayed(String dedupeKey) {
    if (dedupeKey.isEmpty) return;
    _playedDedupeKeys.add(dedupeKey);
    if (_playedDedupeKeys.length > 200) {
      _playedDedupeKeys.remove(_playedDedupeKeys.first);
    }
  }

  void clearAll() {
    for (final timer in _chainTimers.values) {
      timer.cancel();
    }
    _chainTimers.clear();
    for (final flight in _activeSingles) {
      flight.releaseTimer?.cancel();
      flight.controller.stop();
      flight.controller.dispose();
    }
    _activeSingles.clear();
    _chainQueues.clear();
    _scheduleRebuild();
  }

  void enqueue(GiftFlightRequest request) {
    if (request.targetIds.isEmpty) return;

    if (request.dedupeKey != null &&
        request.dedupeKey!.isNotEmpty &&
        _playedDedupeKeys.contains(request.dedupeKey)) {
      return;
    }

    if (request.isFullScreen && request.svgaUrl.isNotEmpty) {
      // Fire FS immediately when possible — the old 480ms delay stacked with
      // SVGA decode and made "sent" feel late even for cached assets.
      final svga = request.svgaUrl;
      scheduleMicrotask(() {
        if (!mounted) return;
        widget.onFullScreenSvga?.call(svga);
      });
    }

    if (request.imageUrl.isEmpty) {
      // Still mark after a successful FS enqueue so peers do not double-play.
      if (request.dedupeKey != null &&
          request.dedupeKey!.isNotEmpty &&
          request.isFullScreen) {
        markPlayed(request.dedupeKey!);
      }
      return;
    }

    final provider = _providerFor(request.imageUrl);
    precacheImage(provider, context).catchError((_) {});

    final chainId = (request.dedupeKey != null && request.dedupeKey!.isNotEmpty)
        ? request.dedupeKey!
        : 'chain_${_chainSeq++}';

    // Claimed before the frame, not inside the callback below: the socket echo
    // and the postgres insert of one gift land in the same frame, and marking
    // late let both of them queue a batch — the room saw the gift fly twice.
    if (request.dedupeKey != null && request.dedupeKey!.isNotEmpty) {
      markPlayed(request.dedupeKey!);
    }

    final isCombo = _noteGiftAndCheckCombo(request.comboKey);
    if (isCombo) _releaseHeldHeroes(comboKey: request.comboKey);
    final hold =
        request.holdAtCenter &&
        !isCombo &&
        _activeSingles.length < _heroMaxActive;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hold) {
        _startHero(request, chainId);
        return;
      }
      final start = request.resolveOffset(request.senderId);
      final qty = request.quantity.clamp(1, 9999);
      final durationMs = _waveFlightMs(qty);
      final waveCount = qty < _maxAnimatedWaves ? qty : _maxAnimatedWaves;

      final waves = <_RunnableBatch>[];
      for (var wave = 0; wave < waveCount; wave++) {
        final batch = _RunnableBatch(chainId: chainId, items: []);
        for (final targetId in request.targetIds) {
          final end = request.resolveOffset(targetId);
          batch.items.add(
            _SinglePending(
              start: start,
              end: end,
              imageUrl: request.imageUrl,
              durationMs: durationMs,
            ),
          );
        }
        if (batch.items.isNotEmpty) {
          waves.add(batch);
        }
      }

      if (waves.isEmpty) return;
      _chainQueues.putIfAbsent(chainId, () => []).addAll(waves);
      _pumpChain(chainId);
    });
  }

  /// Records this gift's time for [comboKey] and says whether it follows the
  /// sender's previous gift closely enough to count as a combo tap.
  bool _noteGiftAndCheckCombo(String comboKey) {
    if (comboKey.isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastGiftAtMs.remove(comboKey);
    _lastGiftAtMs[comboKey] = now;
    if (_lastGiftAtMs.length > 64) {
      _lastGiftAtMs.remove(_lastGiftAtMs.keys.first);
    }
    return last != null && now - last < _comboGapMs;
  }

  /// Sends gifts still sitting in the centre on to their seats: all of them
  /// for a fresh gift taking the centre (after [_heroMinHoldMs]), or right
  /// away for the sender's own combo.
  void _releaseHeldHeroes({String? comboKey}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final flight in _activeSingles) {
      final hero = flight.hero;
      if (hero == null || flight.releaseTimer != null) continue;
      if (flight.controller.value >= hero.holdEnd) continue;
      if (hero.waitingForSvga) {
        // Releasing now would fly the listing PNG away on a gift's first
        // send; keep it for a short look once the SVGA is ready instead.
        hero.releaseRequested = true;
        continue;
      }
      if (comboKey != null) {
        if (hero.comboKey != comboKey) continue;
        _flyHeroNow(flight);
        continue;
      }
      final heldMs = now - hero.startedAtMs;
      final waitMs = _heroPopMs + _heroMinHoldMs - heldMs;
      if (waitMs <= 0) {
        _flyHeroNow(flight);
      } else {
        flight.releaseTimer = Timer(Duration(milliseconds: waitMs), () {
          flight.releaseTimer = null;
          if (!mounted || !_activeSingles.contains(flight)) return;
          _flyHeroNow(flight);
        });
      }
    }
  }

  void _flyHeroNow(_ActiveSingle flight) {
    final hero = flight.hero;
    if (hero == null) return;
    flight.releaseTimer?.cancel();
    flight.releaseTimer = null;
    if (flight.controller.value >= hero.holdEnd) return;
    hero.waitingForSvga = false;
    flight.controller.forward(from: hero.holdEnd);
  }

  /// One icon per receiver, all starting together in the centre; only the
  /// first is drawn until they split up for the flight.
  ///
  /// The hold is the gift's "Show for" time from the dashboard. A gift whose
  /// SVGA is not decoded yet (the first send of it on this phone) pops its
  /// icon and pauses there until the SVGA is ready, and only then starts the
  /// hold — a fixed hold used to end before the download did, so the first
  /// few sends of every gift only ever showed the listing image.
  void _startHero(GiftFlightRequest request, String chainId) {
    if (_activeSingles.length >= _maxActiveFlights) return;
    _releaseHeldHeroes();
    final box = context.findRenderObject() as RenderBox?;
    final size = (box != null && box.hasSize)
        ? box.size
        : MediaQuery.sizeOf(context);
    final center = Offset(size.width / 2, size.height * 0.42);
    final svga = request.svgaUrl.trim();
    final configuredMs = GiftShowDuration.lookup(
      svgaUrl: svga,
      iconUrl: request.imageUrl,
    );
    final ready = svga.isEmpty || _animationReady(svga);
    final holdMs = ready
        ? _resolveHoldMs(configuredMs, svga)
        : (configuredMs > 0 ? configuredMs : _heroHoldMs);
    final totalMs = _heroPopMs + holdMs + _heroFlyMs;
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final qty = request.quantity.clamp(1, 9999);
    final group = <_ActiveSingle>[];
    var index = 0;
    for (final targetId in request.targetIds) {
      if (_activeSingles.length >= _maxActiveFlights) break;
      final flight = _startSingle(
        _SinglePending(
          start: center,
          end: request.resolveOffset(targetId),
          imageUrl: request.imageUrl,
          durationMs: totalMs,
        ),
        chainId,
        hero: _HeroTiming(
          comboKey: request.comboKey,
          popEnd: _heroPopMs / totalMs,
          holdEnd: (_heroPopMs + holdMs) / totalMs,
          startedAtMs: startedAt,
          drawWhileHeld: index == 0,
          quantity: qty,
          svgaUrl: svga,
          waitingForSvga: !ready,
        ),
      );
      group.add(flight);
      index++;
    }
    if (!ready && group.isNotEmpty) _holdUntilSvgaReady(group, svga, configuredMs);
    _scheduleRebuild();
  }

  /// The gift's animation (SVGA or MP4) can play without a network wait.
  static bool _animationReady(String url) => MediaUrlUtil.isVideoUrl(url)
      ? GiftVideoCache.isReady(url)
      : SvgaCache.isInMemory(url);

  static Future<void> _loadAnimation(String url) => MediaUrlUtil.isVideoUrl(url)
      ? GiftVideoCache.file(url)
      : SvgaCache.load(url);

  /// [configuredMs] of 0 means the animation's own length; stills get 3 s.
  int _resolveHoldMs(int configuredMs, String svgaUrl) {
    if (configuredMs > 0) return configuredMs;
    if (svgaUrl.isEmpty) return GiftShowDuration.stillImageMs;
    if (MediaUrlUtil.isVideoUrl(svgaUrl)) {
      final ms = GiftVideoCache.durationMs(svgaUrl);
      if (ms == null) return GiftShowDuration.stillImageMs;
      return ms.clamp(1000, GiftShowDuration.maxMs);
    }
    final params = SvgaCache.peek(svgaUrl)?.params;
    final fps = params?.fps ?? 0;
    final frames = params?.frames ?? 0;
    if (fps <= 0 || frames <= 0) return GiftShowDuration.stillImageMs;
    return (frames * 1000 / fps).round().clamp(1000, GiftShowDuration.maxMs);
  }

  void _holdUntilSvgaReady(
    List<_ActiveSingle> group,
    String svgaUrl,
    int configuredMs,
  ) {
    for (final flight in group) {
      final hero = flight.hero!;
      void pauseAtPop() {
        if (!hero.waitingForSvga) {
          flight.controller.removeListener(pauseAtPop);
          return;
        }
        if (flight.controller.value >= hero.popEnd) {
          flight.controller.removeListener(pauseAtPop);
          flight.controller.stop();
        }
      }

      flight.controller.addListener(pauseAtPop);
    }

    var resumed = false;
    void resume({required bool loaded}) {
      if (resumed) return;
      resumed = true;
      if (!mounted) return;
      final fullHoldMs = loaded
          ? _resolveHoldMs(configuredMs, svgaUrl)
          : (configuredMs > 0 ? configuredMs : GiftShowDuration.stillImageMs);
      for (final flight in group) {
        final hero = flight.hero!;
        // The download wait counts toward the show time instead of being
        // added in front of it, which kept first sends in the centre for
        // 5-13 s. A late SVGA still gets a short look before the flight.
        final waitedMs = DateTime.now().millisecondsSinceEpoch -
            hero.startedAtMs -
            _heroPopMs;
        var holdMs = fullHoldMs - (waitedMs > 0 ? waitedMs : 0);
        if (loaded && holdMs < _heroLateSvgaShowMs) {
          holdMs = _heroLateSvgaShowMs;
        } else if (!loaded && holdMs < 0) {
          holdMs = 0;
        }
        if (hero.releaseRequested && holdMs > _heroReleasedHoldMs) {
          holdMs = _heroReleasedHoldMs;
        }
        final totalMs = _heroPopMs + holdMs + _heroFlyMs;
        hero.waitingForSvga = false;
        if (!loaded) hero.svgaUrl = '';
        if (!_activeSingles.contains(flight)) continue;
        // Released early by a newer gift or a combo tap: already flying.
        if (flight.controller.isAnimating &&
            flight.controller.value >= hero.holdEnd) {
          continue;
        }
        final pastPop = flight.controller.value >= hero.popEnd;
        hero.popEnd = _heroPopMs / totalMs;
        hero.holdEnd = (_heroPopMs + holdMs) / totalMs;
        flight.controller.duration = Duration(milliseconds: totalMs);
        if (pastPop) {
          flight.controller.forward(from: hero.popEnd);
        } else if (!flight.controller.isAnimating) {
          flight.controller.forward();
        }
      }
    }

    _loadAnimation(svgaUrl)
        .timeout(_heroSvgaWait)
        .then(
          (_) => resume(loaded: true),
          onError: (Object _) => resume(loaded: false),
        );
  }

  int _waveFlightMs(int totalQuantity) {
    if (totalQuantity <= 1) return 620;
    if (totalQuantity <= 10) return 480;
    if (totalQuantity <= 30) return 420;
    if (totalQuantity <= 66) return 380;
    if (totalQuantity <= 120) return 340;
    if (totalQuantity <= 200) return 300;
    final logBoost = log(totalQuantity.clamp(51, 9999).toDouble()) / ln10;
    return (280 / (1 + logBoost * 0.25)).round().clamp(240, 300);
  }

  /// Launches one wave of a combo and schedules the next on a fixed gap.
  ///
  /// Waves used to be gated on the previous wave landing, which turned a large
  /// combo into a slow trickle. They now overlap, so the whole combo is a short
  /// burst no matter how big the quantity is.
  void _pumpChain(String chainId) {
    _chainTimers.remove(chainId)?.cancel();

    final queue = _chainQueues[chainId];
    if (queue == null || queue.isEmpty) {
      _chainQueues.remove(chainId);
      return;
    }

    // When the screen is already full of icons, drop the rest of this combo
    // rather than queue work that would only arrive late and cost frames.
    if (_activeSingles.length >= _maxActiveFlights) {
      _chainQueues.remove(chainId);
      return;
    }

    final batch = queue.removeAt(0);
    for (final pending in batch.items) {
      _startSingle(pending, chainId);
    }

    if (queue.isEmpty) {
      _chainQueues.remove(chainId);
    } else {
      _chainTimers[chainId] = Timer(
        const Duration(milliseconds: _waveStaggerMs),
        () {
          if (!mounted) return;
          _pumpChain(chainId);
        },
      );
    }
    if (batch.items.isNotEmpty) _scheduleRebuild();
  }

  _ActiveSingle _startSingle(
    _SinglePending pending,
    String chainId, {
    _HeroTiming? hero,
  }) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: pending.durationMs),
    );

    final flight = _ActiveSingle(
      pending: pending,
      controller: controller,
      chainId: chainId,
      hero: hero,
    );
    _activeSingles.add(flight);
    // A status listener, not forward().whenComplete: releasing a held gift
    // restarts the controller with forward(from:), which cancels the first
    // ticker future so it never completes.
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      flight.releaseTimer?.cancel();
      flight.releaseTimer = null;
      if (!mounted) {
        controller.dispose();
        return;
      }
      _activeSingles.remove(flight);
      controller.dispose();
      _scheduleRebuild();
    });
    controller.forward();
    return flight;
  }

  void _scheduleRebuild() {
    if (_rebuildScheduled || !mounted) return;
    _rebuildScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  ImageProvider _providerFor(String url) {
    final existing = _imageCache[url];
    if (existing != null) return existing;
    if (_imageCache.length >= _maxImageCacheEntries) {
      _imageCache.remove(_imageCache.keys.first);
    }
    // Same rendered URL and cache the gift grid and the catalog prefetch use,
    // so the icon is usually already on disk. The raw URL on the default cache
    // re-downloaded the full-size file, and a flight that ended before it
    // arrived showed nothing at all.
    final rendered =
        SupabaseImageTransform.url(
          url,
          width: 128,
          height: 128,
          resize: 'contain',
          quality: 75,
        ) ??
        url;
    final provider = CachedNetworkImageProvider(
      rendered,
      cacheManager: AppImageCache.manager,
    );
    _imageCache[url] = provider;
    return provider;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_activeSingles.isNotEmpty)
          IgnorePointer(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  for (final flight in _activeSingles)
                    _GiftFlightPaint(
                      key: ValueKey(flight.controller),
                      flight: flight,
                      iconSize: _iconSize,
                      iconHalf: _iconHalf,
                      image: _providerFor(flight.pending.imageUrl),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GiftFlightPaint extends StatelessWidget {
  final _ActiveSingle flight;
  final double iconSize;
  final double iconHalf;
  final ImageProvider image;

  const _GiftFlightPaint({
    super.key,
    required this.flight,
    required this.iconSize,
    required this.iconHalf,
    required this.image,
  });

  double _seatEnterOpacity(double rawT) {
    if (rawT >= 1.0) return 0;
    if (rawT < 0.88) return 1.0;
    return ((1.0 - rawT) / 0.12).clamp(0.0, 1.0);
  }

  double _seatEnterScale(double rawT) {
    if (rawT >= 1.0) return 0;
    if (rawT < 0.88) return 1.0;
    final t = ((1.0 - rawT) / 0.12).clamp(0.0, 1.0);
    return 0.12 + t * 0.88;
  }

  double _linkScale(double rawT) {
    if (rawT < 0.1) return 0.65 + (rawT / 0.1) * 0.55;
    return 1.20;
  }

  double _pathLinkOpacity(double rawT) {
    if (rawT <= 0 || rawT >= 1.0) return 0;
    final appear = rawT < 0.04 ? rawT / 0.04 : 1.0;
    return appear * _seatEnterOpacity(rawT);
  }

  static const TextStyle _heroQtyStyle = TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    height: 1,
    shadows: [
      Shadow(color: Colors.black87, offset: Offset(0, 1.5), blurRadius: 2),
    ],
  );

  Widget _buildHero(_HeroTiming hero, Widget icon) {
    const heroScale = GiftFlightManagerState._heroScale;
    final pending = flight.pending;
    final v = flight.controller.value.clamp(0.0, 1.0);

    if (v < hero.holdEnd) {
      if (!hero.drawWhileHeld) return const SizedBox.shrink();
      final popT = hero.popEnd <= 0
          ? 1.0
          : (v / hero.popEnd).clamp(0.0, 1.0);
      final scale = heroScale * Curves.easeOutBack.transform(popT);
      return Positioned(
        left: pending.start.dx - iconHalf,
        top: pending.start.dy - iconHalf,
        child: Opacity(
          opacity: Curves.easeOut.transform(popT),
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  filterQuality: FilterQuality.low,
                  child: hero.svgaUrl.isEmpty
                      ? icon
                      : _HeroAnimatedIcon(
                          svgaUrl: hero.svgaUrl,
                          icon: icon,
                          size: iconSize * 1.5,
                        ),
                ),
                if (hero.quantity > 1)
                  Positioned(
                    top: iconHalf + iconHalf * heroScale + 4,
                    left: -48,
                    right: -48,
                    child: Center(
                      child: Text('x${hero.quantity}', style: _heroQtyStyle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final flyT = hero.holdEnd >= 1
        ? 1.0
        : ((v - hero.holdEnd) / (1 - hero.holdEnd)).clamp(0.0, 1.0);
    if (flyT >= 1.0) return const SizedBox.shrink();
    final eased = Curves.easeInOut.transform(flyT);
    final pos = Offset.lerp(pending.start, pending.end, eased)!;
    final scale =
        (heroScale + (1.0 - heroScale) * eased) * _seatEnterScale(flyT);
    return Positioned(
      left: pos.dx - iconHalf,
      top: pos.dy - iconHalf,
      child: Opacity(
        opacity: _seatEnterOpacity(flyT),
        child: Transform.scale(
          scale: scale,
          filterQuality: FilterQuality.low,
          child: icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = flight.pending;
    return AnimatedBuilder(
      animation: flight.controller,
      child: Image(
        image: image,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.card_giftcard, color: Colors.amber, size: 44),
      ),
      builder: (context, child) {
        final hero = flight.hero;
        if (hero != null) return _buildHero(hero, child!);
        final rawT = Curves.easeOut.transform(
          flight.controller.value.clamp(0.0, 1.0),
        );
        if (rawT >= 1.0) return const SizedBox.shrink();

        final pos = Offset.lerp(pending.start, pending.end, rawT)!;
        final scale = _linkScale(rawT) * _seatEnterScale(rawT);
        final opacity = _pathLinkOpacity(rawT);

        return Positioned(
          left: pos.dx - iconHalf,
          top: pos.dy - iconHalf,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              filterQuality: FilterQuality.low,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _RunnableBatch {
  final String chainId;
  final List<_SinglePending> items;

  _RunnableBatch({required this.chainId, required this.items});
}

class _SinglePending {
  final Offset start;
  final Offset end;
  final String imageUrl;
  final int durationMs;

  const _SinglePending({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.durationMs,
  });
}

class _ActiveSingle {
  final _SinglePending pending;
  final AnimationController controller;
  final String chainId;

  /// Set for a centre-hold flight, null for a direct one.
  final _HeroTiming? hero;

  /// Pending hand-off from the centre once a newer gift claims it.
  Timer? releaseTimer;

  _ActiveSingle({
    required this.pending,
    required this.controller,
    required this.chainId,
    this.hero,
  });
}

/// Phase boundaries of a centre-hold flight, as fractions of its controller.
/// Re-timed once a first-time SVGA has loaded and its real hold is known.
class _HeroTiming {
  final String comboKey;
  double popEnd;
  double holdEnd;
  final int startedAtMs;
  final bool drawWhileHeld;
  final int quantity;

  /// The gift's animation, played in the centre instead of the still icon.
  /// Cleared when it fails to load, so the icon holds instead.
  String svgaUrl;

  /// Paused after the pop until the SVGA has decoded.
  bool waitingForSvga;

  /// A newer gift asked this one to leave while it was waiting for its SVGA.
  bool releaseRequested = false;

  _HeroTiming({
    required this.comboKey,
    required this.popEnd,
    required this.holdEnd,
    required this.startedAtMs,
    required this.drawWhileHeld,
    required this.quantity,
    this.svgaUrl = '',
    this.waitingForSvga = false,
  });
}

/// The centre preview of a gift that has an animation: the still icon until
/// the SVGA has decoded (first send of a gift downloads it), then the SVGA.
/// A failed decode leaves the icon up.
class _HeroAnimatedIcon extends StatefulWidget {
  final String svgaUrl;
  final Widget icon;
  final double size;

  const _HeroAnimatedIcon({
    required this.svgaUrl,
    required this.icon,
    required this.size,
  });

  @override
  State<_HeroAnimatedIcon> createState() => _HeroAnimatedIconState();
}

class _HeroAnimatedIconState extends State<_HeroAnimatedIcon> {
  bool _loaded = false;

  void _onLoaded() {
    if (mounted && !_loaded) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (!_loaded) widget.icon,
        OverflowBox(
          maxWidth: widget.size,
          maxHeight: widget.size,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: MediaUrlUtil.isVideoUrl(widget.svgaUrl)
                ? GiftVideoPlayer(
                    url: widget.svgaUrl,
                    muted: true,
                    repeat: true,
                    onLoaded: _onLoaded,
                  )
                : RaveSVGAPlayer(
                    resUrl: widget.svgaUrl,
                    fit: BoxFit.contain,
                    repeat: true,
                    filterQuality: FilterQuality.medium,
                    onLoaded: _onLoaded,
                  ),
          ),
        ),
      ],
    );
  }
}
