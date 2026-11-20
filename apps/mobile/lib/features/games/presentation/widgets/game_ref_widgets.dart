import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/providers/su_games_provider.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:sk_live/core/util/svga_cache.dart';
import 'package:video_player/video_player.dart';

abstract final class GameRefLayout {
  static const double designWidth = 750;
  static const String dir = 'assets/design/game';
  static const String bgStatic = '$dir/bg_roulette.webp';
  static const String bgVideo = '$dir/bg_roulette_spin.mp4';
  static const String bigWin = '$dir/banner_bigwin.svga';
  static const String bigWinRtl = '$dir/banner_bigwin_rtl.svga';
  static const String cardFrame = '$dir/card_game_frame.webp';
  static const String plus = '$dir/btn_plus_recharge.webp';
  static const String more = '$dir/btn_more_bg.webp';
  static const String panelTop = '$dir/panel_top_border_gold.webp';
  static const String panelBg = '$dir/panel_bg_green.webp';
  static const String plaque = '$dir/plaque_blank.webp';
  static const String coin = 'assets/rewards/lucky-bag/coin-1.webp';

  static const double refStatusBar = 57;

  static const double refNavTop = 1342;

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  static double topShift(BuildContext context) =>
      MediaQuery.paddingOf(context).top / scaleOf(context) - refStatusBar;

  static double navTop(BuildContext context) {
    final s = scaleOf(context);
    final size = MediaQuery.sizeOf(context);
    final nav = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom + refNavBarHeight(context),
    );
    return (size.height - nav) / s;
  }
}

class GameRefBackground extends ConsumerStatefulWidget {
  const GameRefBackground({super.key});

  @override
  ConsumerState<GameRefBackground> createState() => _GameRefBackgroundState();
}

class _GameRefBackgroundState extends ConsumerState<GameRefBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _resumed = true;
  bool _onScreen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final v = VideoPlayerController.asset(
      GameRefLayout.bgVideo,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = v;
    v
        .initialize()
        .then((_) async {
          if (!mounted) return;
          await v.setVolume(0);
          await v.setLooping(true);
          setState(() => _ready = true);
          _apply();
        })
        .catchError((Object _) {
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _apply();
  }

  void _apply() {
    final v = _video;
    if (v == null || !_ready) return;
    if (_resumed && _onScreen) {
      if (!v.value.isPlaying) v.play();
    } else if (v.value.isPlaying) {
      v.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGameTab =
        ref.watch(bottomNavIndexProvider) == bottomNavIndexForKey('game');
    final onScreen = isGameTab && TickerMode.valuesOf(context).enabled;
    if (onScreen != _onScreen) {
      _onScreen = onScreen;
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
    }
    final s = GameRefLayout.scaleOf(context);
    final v = _video;
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFF0B3A26))),
          Positioned(
            left: 0,
            top: -98 * s,
            width: 750 * s,
            height: 1624 * s,
            child: Image.asset(
              GameRefLayout.bgStatic,
              fit: BoxFit.fill,
              gaplessPlayback: true,
            ),
          ),
          if (v != null && _ready)
            Positioned(
              left: 0,
              top: -110 * s,
              width: 750 * s,
              height: 1632 * 750 / 740 * s,
              child: VideoPlayer(v),
            ),
        ],
      ),
    );
  }
}

class GameRefBigWin extends ConsumerStatefulWidget {
  const GameRefBigWin({super.key});

  static const double cycle = 4.8;
  static const double gapEnd = 0.6;
  static const double inEnd = 0.95;
  static const double outStart = 4.5;

  static double offsetAt(double t) {
    if (t < gapEnd) return 1;
    if (t < inEnd) {
      final p = (t - gapEnd) / (inEnd - gapEnd);
      return 1 - Curves.easeOutCubic.transform(p);
    }
    if (t < outStart) return 0;
    final p = ((t - outStart) / (cycle - outStart)).clamp(0.0, 1.0);
    return -Curves.easeInCubic.transform(p);
  }

  static double svgaProgressAt(double t) =>
      ((t - gapEnd) / 5.0).clamp(0.0, 1.0);

  @override
  ConsumerState<GameRefBigWin> createState() => _GameRefBigWinState();
}

class _GameRefBigWinState extends ConsumerState<GameRefBigWin>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (GameRefBigWin.cycle * 1000).round()),
  )..addListener(_tick);
  SVGAAnimationController? _svga;
  String? _loaded;
  bool _resumed = true;
  bool _onScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _load(String asset) {
    if (_loaded == asset) return;
    _loaded = asset;
    SvgaCache.loadAsset(asset)
        .then((movie) {
          if (!mounted || _loaded != asset) return;
          final c = _svga ?? SVGAAnimationController(vsync: this);
          c.videoItem = movie;
          setState(() => _svga = c);
          _tick();
        })
        .catchError((Object _) {});
  }

  void _tick() {
    final t = _cycle.value * GameRefBigWin.cycle;
    _svga?.value = GameRefBigWin.svgaProgressAt(t);
  }

  void _apply() {
    if (_resumed && _onScreen) {
      if (!_cycle.isAnimating) _cycle.repeat();
    } else if (_cycle.isAnimating) {
      _cycle.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cycle.dispose();
    _svga?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _load(rtl ? GameRefLayout.bigWinRtl : GameRefLayout.bigWin);
    final onScreen =
        ref.watch(bottomNavIndexProvider) == bottomNavIndexForKey('game') &&
        TickerMode.valuesOf(context).enabled;
    if (onScreen != _onScreen) {
      _onScreen = onScreen;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _apply();
      });
    }
    final svga = _svga;
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: _cycle,
            builder: (context, child) {
              final x = GameRefBigWin.offsetAt(
                _cycle.value * GameRefBigWin.cycle,
              );
              if (x >= 1 || x <= -1) return const SizedBox.shrink();
              return Transform.translate(
                offset: Offset((rtl ? -x : x) * box.maxWidth, 0),
                child: child,
              );
            },
            child: svga == null
                ? const SizedBox.shrink()
                : SVGAImage(svga, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }
}

class GameRefTopBar extends ConsumerWidget {
  const GameRefTopBar({super.key, required this.onRecharge});

  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = GameRefLayout.scaleOf(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final avatar = profile?['avatar_url']?.toString() ?? '';
    final name = profile?['username']?.toString() ?? '';
    final coins = (profile?['coins'] as num?)?.toInt() ?? 0;
    final vip = (profile?['vip_level'] as num?)?.toInt() ?? 0;
    final badge = vip > 0
        ? ref.watch(vipBadgeProvider(vip)).valueOrNull ?? ''
        : '';
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '';

    return SizedBox(
      width: 750 * s,
      height: 83 * s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 50 * s,
            top: 0,
            width: 83 * s,
            height: 83 * s,
            child: ClipOval(
              child: ColoredBox(
                color: const Color(0xFF5B4FC8),
                child: avatar.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: avatar,
                        fit: BoxFit.cover,
                        transformWidth: 160,
                        transformHeight: 160,
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 44 * s,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 195 * s,
            top: 20 * s,
            width: 203 * s,
            height: 45 * s,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22.5 * s),
              ),
            ),
          ),
          PositionedDirectional(
            start: 164 * s,
            top: 18 * s,
            width: 46 * s,
            height: 46 * s,
            child: Image.asset(GameRefLayout.coin, fit: BoxFit.contain),
          ),
          PositionedDirectional(
            start: 224 * s,
            top: 20 * s,
            width: 125 * s,
            height: 45 * s,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                NumberFormatter.format(coins),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFF7EED4),
                  fontSize: 29 * s,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 355 * s,
            top: 22 * s,
            width: 40 * s,
            height: 40 * s,
            child: GestureDetector(
              onTap: onRecharge,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(GameRefLayout.plus, fit: BoxFit.contain),
            ),
          ),
          if (badge.isNotEmpty)
            PositionedDirectional(
              start: 420 * s,
              top: 13 * s,
              width: 66 * s,
              height: 59 * s,
              child: AppNetworkImage(
                imageUrl: badge,
                fit: BoxFit.contain,
                transformWidth: 132,
              ),
            ),
        ],
      ),
    );
  }
}

class GameRefMoreButton extends StatelessWidget {
  const GameRefMoreButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = GameRefLayout.scaleOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 104 * s,
        height: 46 * s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(GameRefLayout.more, fit: BoxFit.fill),
            PositionedDirectional(
              start: 27 * s,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xFFF3DEA6),
                    fontSize: 32 * s,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameRefCard extends StatelessWidget {
  const GameRefCard({
    super.key,
    required this.game,
    required this.scale,
    required this.emphasis,
    required this.onTap,
  });

  final SuGameItem game;
  final double scale;

  final double emphasis;
  final VoidCallback onTap;

  static const double width = 208;
  static const double height = 268;
  static const double sideScale = 172 / 208;

  @override
  Widget build(BuildContext context) {
    final s = GameRefLayout.scaleOf(context) * scale;
    final nameColor = Color.lerp(
      const Color(0xFFE1F49A),
      const Color(0xFFEAF48F),
      emphasis,
    )!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width * s,
        height: height * s,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                GameRefLayout.cardFrame,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              left: 35 * s,
              top: 38 * s,
              width: 138 * s,
              height: 140 * s,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12 * s),
                child: game.iconUrl.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: game.iconUrl,
                        fit: BoxFit.cover,
                        transformWidth: 220,
                        transformHeight: 220,
                        memCacheWidth: 220,
                        placeholder: (_, _) =>
                            const ColoredBox(color: Color(0xFF0E4A33)),
                        errorWidget: (_, _, _) => _fallbackIcon(s),
                      )
                    : _fallbackIcon(s),
              ),
            ),
            Positioned(
              left: 14 * s,
              right: 14 * s,
              top: 200 * s,
              height: 40 * s,
              child: Center(
                child: Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: nameColor,
                    fontSize: 33 * s,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon(double s) => ColoredBox(
    color: const Color(0xFF0E4A33),
    child: Icon(
      game.isRupee ? Iconsax.coin : Icons.sports_esports,
      color: Colors.white70,
      size: 56 * s,
    ),
  );
}

class GameRefCarousel extends ConsumerStatefulWidget {
  const GameRefCarousel({super.key, required this.games, required this.onOpen});

  final List<SuGameItem> games;
  final ValueChanged<SuGameItem> onOpen;

  static const double pitch = 211;

  static const int startRounds = 100;

  static int startPage(int count) => count <= 1 ? 0 : count * startRounds + 1;

  static double dimAt(double d) => ((d - 1).clamp(0.0, 1.0)) * 0.45;

  @override
  ConsumerState<GameRefCarousel> createState() => _GameRefCarouselState();
}

class _GameRefCarouselState extends ConsumerState<GameRefCarousel> {
  late PageController _pages = _controllerFor(widget.games.length);
  late int _count = widget.games.length;
  bool _wasOnGameTab = false;

  PageController _controllerFor(int count) => PageController(
    viewportFraction: GameRefCarousel.pitch / GameRefLayout.designWidth,
    initialPage: GameRefCarousel.startPage(count),
  );

  @override
  void didUpdateWidget(covariant GameRefCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.games.length != _count) {
      final old = _pages;
      _count = widget.games.length;
      _pages = _controllerFor(_count);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _resetToStart() {
    if (!_pages.hasClients) return;
    _pages.jumpToPage(GameRefCarousel.startPage(_count));
  }

  @override
  Widget build(BuildContext context) {
    final onGameTab =
        ref.watch(bottomNavIndexProvider) == bottomNavIndexForKey('game');
    if (onGameTab && !_wasOnGameTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetToStart();
      });
    }
    _wasOnGameTab = onGameTab;

    final s = GameRefLayout.scaleOf(context);
    final games = widget.games;
    final n = games.length;
    return SizedBox(
      height: GameRefCard.height * s,
      child: PageView.builder(
        key: ValueKey(n),
        controller: _pages,
        pageSnapping: false,
        physics: const _CardSnapPhysics(
          fraction: GameRefCarousel.pitch / GameRefLayout.designWidth,
        ),
        allowImplicitScrolling: true,
        itemCount: n <= 1 ? n : null,
        itemBuilder: (context, i) {
          final game = games[i % n];
          return AnimatedBuilder(
            animation: _pages,
            builder: (context, _) {
              final page = _pages.hasClients && _pages.position.haveDimensions
                  ? (_pages.page ?? _pages.initialPage.toDouble())
                  : _pages.initialPage.toDouble();
              final dist = (page - i).abs();
              final d = dist.clamp(0.0, 1.0);
              final scale = 1 - (1 - GameRefCard.sideScale) * d;
              final dim = GameRefCarousel.dimAt(dist);
              Widget card = GameRefCard(
                game: game,
                scale: scale,
                emphasis: 1 - d,
                onTap: () => widget.onOpen(game),
              );
              if (dim > 0) {
                final k = 1 - dim;
                card = ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    k, 0, 0, 0, 0,
                    0, k, 0, 0, 0,
                    0, 0, k, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: card,
                );
              }
              return OverflowBox(
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                alignment: Alignment.bottomCenter,
                child: card,
              );
            },
          );
        },
      ),
    );
  }
}

class _CardSnapPhysics extends ScrollPhysics {
  const _CardSnapPhysics({required this.fraction, super.parent});

  final double fraction;

  static const double carry = 0.12;

  @override
  _CardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _CardSnapPhysics(fraction: fraction, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final extent = position.viewportDimension * fraction;
    if (extent <= 0) return super.createBallisticSimulation(position, velocity);
    final projected = position.pixels + velocity * carry;
    final target = ((projected / extent).roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class GameRefMorePanel extends StatelessWidget {
  const GameRefMorePanel({
    super.key,
    required this.categories,
    required this.onOpen,
  });

  final List<SuGameCategory> categories;
  final ValueChanged<SuGameItem> onOpen;

  static Future<void> show(
    BuildContext context, {
    required List<SuGameCategory> categories,
    required ValueChanged<SuGameItem> onOpen,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => GameRefMorePanel(categories: categories, onOpen: onOpen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final s = GameRefLayout.scaleOf(context);
    final height = media.size.height * (1 - 705 / 1626);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 40 * s,
            bottom: 0,
            child: Image.asset(
              GameRefLayout.panelBg,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 40 * s,
            bottom: 0,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                0,
                25 * s,
                0,
                media.padding.bottom + 40 * s,
              ),
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) SizedBox(height: 74 * s - 46 * s),
                  _PanelSection(
                    category: categories[i],
                    scale: s,
                    onOpen: (g) {
                      Navigator.of(context).pop();
                      onOpen(g);
                    },
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 162 * s,
            child: IgnorePointer(
              child: Image.asset(GameRefLayout.panelTop, fit: BoxFit.fill),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.category,
    required this.scale,
    required this.onOpen,
  });

  final SuGameCategory category;
  final double scale;
  final ValueChanged<SuGameItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final games = category.games;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 430 * s,
            height: 78 * s,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(GameRefLayout.plaque, fit: BoxFit.fill),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 90 * s),
                  child: Center(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFE8F3A0),
                        fontSize: 32 * s,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 22 * s),
        Center(
          child: SizedBox(
            width: 172 * 4 * s + 1,
            child: Wrap(
              spacing: 0,
              runSpacing: 0,
              children: [
                for (final g in games)
                  SizedBox(
                    width: 172 * s,
                    height: 189 * s,
                    child: GestureDetector(
                      onTap: () => onOpen(g),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18 * s),
                            child: SizedBox.square(
                              dimension: 121 * s,
                              child: g.iconUrl.isNotEmpty
                                  ? AppNetworkImage(
                                      imageUrl: g.iconUrl,
                                      fit: BoxFit.cover,
                                      transformWidth: 220,
                                      transformHeight: 220,
                                      memCacheWidth: 220,
                                      placeholder: (_, _) => const ColoredBox(
                                        color: Color(0xFF0E4A33),
                                      ),
                                      errorWidget: (_, _, _) => ColoredBox(
                                        color: const Color(0xFF0E4A33),
                                        child: Icon(
                                          g.isRupee
                                              ? Iconsax.coin
                                              : Icons.sports_esports,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    )
                                  : ColoredBox(
                                      color: const Color(0xFF0E4A33),
                                      child: Icon(
                                        g.isRupee
                                            ? Iconsax.coin
                                            : Icons.sports_esports,
                                        color: Colors.white70,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 8 * s),
                          Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFD4EFA5),
                              fontSize: 21 * s,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
