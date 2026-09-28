import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GiftFlightRequest {
  final String? dedupeKey;
  final String senderId;
  final List<String> targetIds;
  final String imageUrl;
  final int quantity;
  final bool isFullScreen;
  final String svgaUrl;
  final Offset Function(String userId) resolveOffset;

  const GiftFlightRequest({
    this.dedupeKey,
    required this.senderId,
    required this.targetIds,
    required this.imageUrl,
    required this.quantity,
    this.isFullScreen = false,
    this.svgaUrl = '',
    required this.resolveOffset,
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

  final Map<String, List<_RunnableBatch>> _chainQueues = {};
  final Map<String, int> _chainWaveRemaining = {};
  final List<_ActiveSingle> _activeSingles = [];
  final Set<String> _playedDedupeKeys = {};
  final Map<String, ImageProvider> _imageCache = {};
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
    for (final f in _activeSingles) {
      f.controller.dispose();
    }
    _activeSingles.clear();
    _chainQueues.clear();
    _chainWaveRemaining.clear();
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
    for (final flight in _activeSingles) {
      flight.controller.stop();
      flight.controller.dispose();
    }
    _activeSingles.clear();
    _chainQueues.clear();
    _chainWaveRemaining.clear();
    _scheduleRebuild();
  }

  void enqueue(GiftFlightRequest request) {
    if (request.targetIds.isEmpty) return;

    if (request.dedupeKey != null && request.dedupeKey!.isNotEmpty) {
      if (_playedDedupeKeys.contains(request.dedupeKey)) return;
      markPlayed(request.dedupeKey!);
    }

    if (request.isFullScreen && request.svgaUrl.isNotEmpty) {
      final svga = request.svgaUrl;
      Future<void>.delayed(const Duration(milliseconds: 480), () {
        if (!mounted) return;
        widget.onFullScreenSvga?.call(svga);
      });
    }

    if (request.imageUrl.isEmpty) return;

    final provider = _providerFor(request.imageUrl);
    precacheImage(provider, context).catchError((_) {});

    final chainId = (request.dedupeKey != null && request.dedupeKey!.isNotEmpty)
        ? request.dedupeKey!
        : 'chain_${_chainSeq++}';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final start = request.resolveOffset(request.senderId);
      final qty = request.quantity.clamp(1, 9999);
      final durationMs = _waveFlightMs(qty);

      final waves = <_RunnableBatch>[];
      for (var wave = 0; wave < qty; wave++) {
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
      _tryStartNextWave(chainId);
    });
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

  void _tryStartNextWave(String chainId) {
    if ((_chainWaveRemaining[chainId] ?? 0) > 0) return;

    final queue = _chainQueues[chainId];
    if (queue == null || queue.isEmpty) {
      _chainQueues.remove(chainId);
      _chainWaveRemaining.remove(chainId);
      return;
    }

    final batch = queue.removeAt(0);
    if (queue.isEmpty) {
      _chainQueues.remove(chainId);
    }

    if (batch.items.isEmpty) {
      _tryStartNextWave(chainId);
      return;
    }

    _chainWaveRemaining[chainId] = batch.items.length;
    for (final pending in batch.items) {
      _startSingle(pending, chainId);
    }
    _scheduleRebuild();
  }

  void _onWaveItemDone(String chainId) {
    final left = (_chainWaveRemaining[chainId] ?? 1) - 1;
    if (left <= 0) {
      _chainWaveRemaining.remove(chainId);
      _tryStartNextWave(chainId);
    } else {
      _chainWaveRemaining[chainId] = left;
    }
  }

  void _startSingle(_SinglePending pending, String chainId) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: pending.durationMs),
    );

    final flight = _ActiveSingle(
      pending: pending,
      controller: controller,
      chainId: chainId,
    );
    _activeSingles.add(flight);
    controller.forward().whenComplete(() {
      if (!mounted) {
        controller.dispose();
        return;
      }
      _activeSingles.remove(flight);
      controller.dispose();
      _onWaveItemDone(chainId);
      _scheduleRebuild();
    });
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
    return _imageCache.putIfAbsent(url, () => CachedNetworkImageProvider(url));
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

  const _ActiveSingle({
    required this.pending,
    required this.controller,
    required this.chainId,
  });
}
