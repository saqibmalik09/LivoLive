import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/models/global_win_announcement.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/util/global_win_svga_util.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/patti_room_navigator.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';
import 'package:sk_live/l10n/app_localizations.dart';

class GlobalWinEntranceOverlay extends ConsumerStatefulWidget {
  final GlobalWinAnnouncement win;
  final VoidCallback onFinished;

  const GlobalWinEntranceOverlay({
    super.key,
    required this.win,
    required this.onFinished,
  });

  @override
  ConsumerState<GlobalWinEntranceOverlay> createState() =>
      _GlobalWinEntranceOverlayState();
}

class _GlobalWinEntranceOverlayState
    extends ConsumerState<GlobalWinEntranceOverlay>
    with TickerProviderStateMixin {
  static const _bannerHeight = 100.0;

  static const _gameBannerWidthFactor = 0.84;
  static const _displayDuration = Duration(milliseconds: 5500);

  // 1500ms was not enough for a cold decode and the banner silently skipped its
  // animation. Retries now attach to the in-flight decode in SvgaCache rather
  // than starting a fresh one, so waiting longer costs nothing.
  static const _svgaLoadTimeout = Duration(milliseconds: 2500);
  static const _svgaLoadAttempts = 2;

  GlobalKey<RaveSVGAPlayerState> _svgaKey = GlobalKey<RaveSVGAPlayerState>();

  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _finished = false;
  bool _svgaReady = false;
  bool _playbackStarted = false;
  Timer? _svgaLoadTimer;
  int _svgaAttempt = 1;

  static const _pauseWeight = 8.0;
  static const _enterWeight = 14.0;
  static const _holdWeight = 45.0;
  static const _exitWeight = 33.0;

  static const _luckyAvatarSlot = 'Avatar';
  static const _luckyTextSlot = 'test';
  MovieEntity? _luckyMovie;
  ui.Image? _luckyAvatar;

  String? get _luckyTierAsset => GlobalWinSvgaUtil.isLucky(widget.win.variant)
      ? GlobalWinSvgaUtil.luckyTierAsset(widget.win.bonusMultiplier)
      : null;

  bool get _isGameBanner => widget.win.variant == 'game';

  void _fillLuckySlots(MovieEntity movie) {
    _luckyMovie = movie;
    movie.dynamicItem.reset();
    movie.dynamicItem.setText(
      globalWinLuckyBannerText(widget.win),
      _luckyTextSlot,
    );
    final avatar = _luckyAvatar;
    if (avatar != null) {
      movie.dynamicItem.setImage(avatar, _luckyAvatarSlot);
    }
  }

  Future<void> _loadLuckyAvatar() async {
    final url = widget.win.avatarUrl;
    if (url == null || url.isEmpty) return;
    final image = await _circleAvatarImage(url);
    if (image == null) return;
    if (!mounted) {
      image.dispose();
      return;
    }
    _luckyAvatar = image;
    _luckyMovie?.dynamicItem.setImage(image, _luckyAvatarSlot);
  }

  double _profileLeftPadding(String variant) {
    if (variant == 'game') return 46;
    return 24;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _displayDuration);

    _slideAnimation = _buildSlideAnimation(_holdWeight);
    _fadeAnimation = _buildFadeAnimation(_holdWeight);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finishOnce();
      }
    });

    _armSvgaLoadTimer();
    if (_luckyTierAsset != null) unawaited(_loadLuckyAvatar());
  }

  void _armSvgaLoadTimer() {
    _svgaLoadTimer?.cancel();
    _svgaLoadTimer = Timer(_svgaLoadTimeout, _onSvgaLoadTimeout);
  }

  void _onSvgaLoadTimeout() {
    if (!mounted || _svgaReady) return;
    if (_svgaAttempt >= _svgaLoadAttempts) {
      debugPrint(
        'GlobalWin patti skipped: SVGA never loaded (${widget.win.id})',
      );
      _finishOnce();
      return;
    }
    setState(() {
      _svgaAttempt++;
      _svgaKey = GlobalKey<RaveSVGAPlayerState>();
    });
    _armSvgaLoadTimer();
  }

  Animation<Offset> _buildSlideAnimation(double holdWeight) {
    return TweenSequence<Offset>([
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(1.0, 0.0)),
        weight: _pauseWeight,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: _enterWeight,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: holdWeight,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-1.5, 0.0),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: _exitWeight,
      ),
    ]).animate(_controller);
  }

  Animation<double> _buildFadeAnimation(double holdWeight) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: _pauseWeight,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: _enterWeight,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: holdWeight),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: _exitWeight,
      ),
    ]).animate(_controller);
  }

  void _onSvgaLoaded() {
    if (!mounted || _svgaReady) return;
    setState(() => _svgaReady = true);
    _startPlayback();
  }

  void _startPlayback() {
    if (_playbackStarted || !mounted || !_svgaReady) return;
    _playbackStarted = true;
    _svgaLoadTimer?.cancel();
    _svgaLoadTimer = null;

    final svga = _svgaKey.currentState;
    svga?.syncDurationTo(_displayDuration);
    svga?.play();
    _controller.forward(from: 0);
  }

  void _finishOnce() {
    if (_finished || !mounted) return;
    _finished = true;
    _svgaLoadTimer?.cancel();
    _svgaLoadTimer = null;
    widget.onFinished();
  }

  static const _swipeDuration = Duration(milliseconds: 200);
  static const _swipeAwayShare = 0.3;
  static const _swipeAwayHeightShare = 0.5;
  static const _swipeFlingSpeed = 800.0;

  late final AnimationController _swipeController = AnimationController(
    vsync: this,
    duration: _swipeDuration,
  )..addListener(_onSwipeTick);
  Offset _drag = Offset.zero;
  Offset _swipeFrom = Offset.zero;
  Offset _swipeTo = Offset.zero;
  bool _swipingAway = false;

  void _onSwipeTick() {
    final t = Curves.easeOut.transform(_swipeController.value);
    setState(() => _drag = Offset.lerp(_swipeFrom, _swipeTo, t)!);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_swipingAway || _finished) return;
    _swipeController.stop();
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d, Size screen, double bannerHeight) {
    if (_swipingAway || _finished) return;
    final v = d.velocity.pixelsPerSecond;
    final fling = v.distance >= _swipeFlingSpeed;
    final sideways = _drag.dx.abs() >= _drag.dy.abs();
    final far = sideways
        ? _drag.dx.abs() >= screen.width * _swipeAwayShare
        : _drag.dy.abs() >= bannerHeight * _swipeAwayHeightShare;
    if (!far && !fling) {
      _animateSwipe(Offset.zero, away: false);
      return;
    }
    final dir = fling ? v : _drag;
    final out = dir.dx.abs() >= dir.dy.abs()
        ? Offset(dir.dx.sign * screen.width * 1.2, _drag.dy)
        : Offset(_drag.dx, dir.dy.sign * (bannerHeight * 1.5 + 120));
    _animateSwipe(out, away: true);
  }

  void _animateSwipe(Offset to, {required bool away}) {
    _swipingAway = away;
    _swipeFrom = _drag;
    _swipeTo = to;
    _swipeController.forward(from: 0).whenCompleteOrCancel(() {
      if (away && mounted) _finishOnce();
    });
  }

  void _confirmAndOpenRoom(String roomId, {required bool inRoom}) {
    if (_roomConfirmOpen.value) return;
    final navCtx = AppRouter.navigatorKey.currentContext;
    if (navCtx == null) return;
    final l10n = AppLocalizations.of(navCtx);
    unawaited(
      showGlobalWinRoomConfirm(
        navCtx,
        roomId: roomId,
        title: inRoom
            ? l10n.topBanner_leaveRoomConfirm
            : l10n.topBanner_enterRoomConfirm,
      ),
    );
  }

  Widget _buildAvatar(GlobalWinAnnouncement win) {
    final avatar = _WinAvatar(avatarUrl: win.avatarUrl);
    if (win.variant != 'game') return avatar;

    return Transform.translate(offset: const Offset(5, 5), child: avatar);
  }

  @override
  void dispose() {
    _svgaLoadTimer?.cancel();
    _luckyMovie?.dynamicItem.reset();
    _luckyAvatar?.dispose();
    _swipeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The host wraps the whole app, so at status-bar height this banner landed
    // on top of each screen's own header — covering the Hot/Room/Event tabs and
    // the search button on Home. Drop it below a standard toolbar so it passes
    // under the navigation instead of through it.
    //
    // Inside a room, though, that same strip is where the mic grid starts, so
    // the banner came down across the top row of seats. In a room it rides at
    // the very top instead; everywhere else it keeps the toolbar offset.
    final liveRoomId = ref.watch(currentLiveRoomIdProvider);
    final inRoom = liveRoomId != null && liveRoomId.toString().isNotEmpty;
    final top =
        MediaQuery.paddingOf(context).top + (inRoom ? 0.0 : kToolbarHeight + 8);
    // This entrance banner stays at the top. Moving it to the bottom was tried
    // and rejected: it is the *bonus/win* animation that belongs lower, not
    // this one, and at the bottom it covered the gift bar.
    final win = widget.win;
    final userId = win.userId;
    final svgaAsset = GlobalWinSvgaUtil.pickBannerAsset(variant: win.variant);
    final luckyTierAsset = _luckyTierAsset;
    final isGameBanner = _isGameBanner;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bannerHeight = luckyTierAsset != null
        ? screenWidth * 240 / 750
        : isGameBanner
        ? screenWidth * _gameBannerWidthFactor * 81 / 375
        : _bannerHeight;
    final contentLeft = _profileLeftPadding(win.variant);
    final badgesAsync = userId != null
        ? ref.watch(userBadgesProvider(userId))
        : const AsyncValue<List<UserBadgeModel>>.data([]);

    final banner = Opacity(
      opacity: _svgaReady ? 1 : 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: luckyTierAsset != null
              ? RaveSVGAPlayer(
                  key: _svgaKey,
                  resUrl: luckyTierAsset,
                  fit: BoxFit.fill,
                  repeat: false,
                  autoPlay: false,
                  onLoaded: _onSvgaLoaded,
                  onMovieLoaded: _fillLuckySlots,
                )
              : isGameBanner
              ? Center(
                  child: SizedBox(
                    width: screenWidth * _gameBannerWidthFactor,
                    child: _GameWinBanner(win: win, onReady: _onSvgaLoaded),
                  ),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    RaveSVGAPlayer(
                      key: _svgaKey,
                      resUrl: svgaAsset,
                      fit: BoxFit.contain,
                      repeat: false,
                      autoPlay: false,
                      onLoaded: _onSvgaLoaded,
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: contentLeft, right: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAvatar(win),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          win.username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black87,
                                                offset: Offset(1, 1),
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        badgesAsync.when(
                                          data: (badges) {
                                            if (badges.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return Wrap(
                                              spacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: badges
                                                  .take(4)
                                                  .map(
                                                    (b) =>
                                                        UserBadgeChip(badge: b),
                                                  )
                                                  .toList(),
                                            );
                                          },
                                          loading: () =>
                                              const SizedBox(height: 14),
                                          error: (_, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '+${NumberFormatter.format(win.rewardCoins)}',
                                              style: const TextStyle(
                                                color: Color(0xFFFFD700),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black87,
                                                    offset: Offset(1, 1),
                                                    blurRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _Pill(label: win.badgeLabel),
                                            const SizedBox(width: 4),
                                            _Pill(label: win.tierLabel),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    final roomId = win.roomId;
    final canOpen = roomId != null && roomId.isNotEmpty;
    final allowTap =
        canOpen &&
        (liveRoomId == null || liveRoomId.toString() != roomId.toString());

    final EdgeInsets touchArea = luckyTierAsset != null
        ? EdgeInsets.fromLTRB(
            screenWidth * 66 / 750,
            bannerHeight * 34 / 240,
            0,
            bannerHeight * 34 / 240,
          )
        : isGameBanner
        ? EdgeInsets.symmetric(
            horizontal: screenWidth * (1 - _gameBannerWidthFactor) / 2,
          )
        : const EdgeInsets.symmetric(horizontal: 72);
    final screen = MediaQuery.sizeOf(context);

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: bannerHeight,
      child: ValueListenableBuilder<bool>(
        valueListenable: _roomConfirmOpen,
        builder: (context, confirmOpen, _) => Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            IgnorePointer(
              child: ColorFiltered(
                colorFilter: confirmOpen ? _dimmedBanner : _plainBanner,
                child: Opacity(
                  opacity: _swipingAway
                      ? 1 - _swipeController.value.clamp(0.0, 1.0)
                      : 1,
                  child: Transform.translate(offset: _drag, child: banner),
                ),
              ),
            ),
            if (_svgaReady && !_finished)
              Positioned(
                left: touchArea.left,
                right: touchArea.right,
                top: touchArea.top,
                bottom: touchArea.bottom,
                child: IgnorePointer(
                  ignoring: confirmOpen || _swipingAway,
                  child: GestureDetector(
                    key: const ValueKey('global-win-banner-touch'),
                    behavior: HitTestBehavior.opaque,
                    onTap: allowTap
                        ? () => _confirmAndOpenRoom(roomId, inRoom: inRoom)
                        : null,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: (d) => _onPanEnd(d, screen, bannerHeight),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final ValueNotifier<bool> _roomConfirmOpen = ValueNotifier<bool>(false);

const ColorFilter _plainBanner = ColorFilter.matrix(<double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
]);

const ColorFilter _dimmedBanner = ColorFilter.matrix(<double>[
  0.4, 0, 0, 0, 0,
  0, 0.4, 0, 0, 0,
  0, 0, 0.4, 0, 0,
  0, 0, 0, 1, 0,
]);

Future<void> showGlobalWinRoomConfirm(
  BuildContext navCtx, {
  required String roomId,
  required String title,
}) async {
  if (_roomConfirmOpen.value) return;
  _roomConfirmOpen.value = true;
  try {
    await showGeneralDialog<void>(
      context: navCtx,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(navCtx).modalBarrierDismissLabel,
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogCtx, _, _) => Consumer(
        builder: (dialogCtx, dialogRef, _) => GlobalWinRoomConfirmDialog(
          title: title,
          onConfirm: () {
            unawaited(
              PattiRoomNavigator.openRoom(navCtx, roomId, ref: dialogRef),
            );
            Navigator.of(dialogCtx).pop();
          },
          onCancel: () => Navigator.of(dialogCtx).pop(),
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        );
      },
    );
  } finally {
    _roomConfirmOpen.value = false;
  }
}

class GlobalWinRoomConfirmDialog extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const GlobalWinRoomConfirmDialog({
    super.key,
    required this.title,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 750;
    final l10n = AppLocalizations.of(context);
    Widget button(String label, Color color, double height, VoidCallback tap) {
      return SizedBox(
        width: 392 * s,
        height: height * s,
        child: Material(
          color: color,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27 * s,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: const Alignment(0, 0.03),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25 * s),
        child: SizedBox(
          width: 538 * s,
          child: Padding(
            padding: EdgeInsets.fromLTRB(27 * s, 54 * s, 27 * s, 55 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF1E1E1E),
                    fontSize: 25 * s,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 49 * s),
                button(
                  l10n.common_confirm,
                  const Color(0xFF006E63),
                  83,
                  onConfirm,
                ),
                SizedBox(height: 15 * s),
                button(
                  l10n.common_cancel,
                  const Color(0xFFD7D7D7),
                  84,
                  onCancel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WinAvatar extends StatelessWidget {
  final String? avatarUrl;

  const _WinAvatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Icon(Icons.person, color: Colors.white24),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.person, color: Colors.white54),
              )
            : const Icon(Icons.person, color: Colors.white54),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

@visibleForTesting
TextPainter globalWinLuckyBannerText(GlobalWinAnnouncement win) {
  const shadow = [
    Shadow(color: Color(0xE6000000), offset: Offset(1, 1), blurRadius: 3),
    Shadow(color: Color(0x99000000), blurRadius: 6),
  ];
  final coinsColor =
      GlobalWinSvgaUtil.luckyTierAsset(win.bonusMultiplier) ==
          GlobalWinSvgaUtil.luckyX250Asset
      ? Colors.white
      : const Color(0xFFFFE14D);
  final chars = win.username.characters;
  final name = chars.length > 14 ? '${chars.take(14)}…' : win.username;
  return TextPainter(
    text: TextSpan(
      children: [
        TextSpan(
          text: name,
          style: const TextStyle(
            fontFamily: 'Roboto',
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            height: 1.15,
            shadows: shadow,
          ),
        ),
        const TextSpan(text: '\n'),
        TextSpan(
          text: '+${NumberFormatter.format(win.rewardCoins)}',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: coinsColor,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
            shadows: shadow,
          ),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: 250);
}

Future<ui.Image?> _circleAvatarImage(String url) async {
  const size = 160;
  try {
    final completer = Completer<ImageInfo>();
    final stream = CachedNetworkImageProvider(
      url,
      maxWidth: size,
      maxHeight: size,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info);
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final info = await completer.future.timeout(const Duration(seconds: 8));
    final src = info.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const rect = Rect.fromLTWH(0, 0, size + 0.0, size + 0.0);
    canvas.clipPath(Path()..addOval(rect));
    final side = src.width < src.height ? src.width : src.height;
    final srcRect = Rect.fromLTWH(
      (src.width - side) / 2,
      (src.height - side) / 2,
      side.toDouble(),
      side.toDouble(),
    );
    canvas.drawImageRect(
      src,
      srcRect,
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final image = await recorder.endRecording().toImage(size, size);
    info.dispose();
    return image;
  } catch (e) {
    debugPrint('GlobalWin lucky avatar failed: $e');
    return null;
  }
}

class _GameWinBanner extends StatefulWidget {
  final GlobalWinAnnouncement win;
  final VoidCallback onReady;

  const _GameWinBanner({required this.win, required this.onReady});

  @override
  State<_GameWinBanner> createState() => _GameWinBannerState();
}

class _GameWinBannerState extends State<_GameWinBanner> {
  bool _ready = false;

  void _markReady() {
    if (_ready) return;
    _ready = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.win;
    const shadow = [
      Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 2),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = w * 81 / 375;
        final avatar = h * 0.42;
        return Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  GlobalWinSvgaUtil.gameBannerImage,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, sync) {
                    if (frame != null || sync) _markReady();
                    return child;
                  },
                ),
                Positioned(
                  left: w * 0.235,
                  right: w * 0.085,
                  top: h * 0.30,
                  bottom: h * 0.11,
                  child: Row(
                    children: [
                      Container(
                        width: avatar,
                        height: avatar,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 1.2,
                          ),
                        ),
                        child: ClipOval(child: _WinAvatarImage(win.avatarUrl)),
                      ),
                      SizedBox(width: w * 0.02),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: win.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '  +${NumberFormatter.format(win.rewardCoins)}  ',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD34D),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: win.sourceLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: h * 0.22,
                              shadows: shadow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WinAvatarImage extends StatelessWidget {
  final String? url;

  const _WinAvatarImage(this.url);

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return const ColoredBox(
        color: Color(0x33FFFFFF),
        child: Icon(Icons.person, color: Colors.white70),
      );
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      memCacheWidth: 96,
      placeholder: (context, url) => const ColoredBox(color: Color(0x33FFFFFF)),
      errorWidget: (context, url, error) =>
          const Icon(Icons.person, color: Colors.white70),
    );
  }
}
