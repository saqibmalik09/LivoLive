import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/models/global_win_announcement.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/util/global_win_svga_util.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/patti_room_navigator.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/core/widgets/user_badge_chip.dart';

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
    with SingleTickerProviderStateMixin {
  static const _bannerHeight = 100.0;
  static const _displayDuration = Duration(milliseconds: 5500);

  static const _svgaLoadTimeout = Duration(milliseconds: 1500);
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

  Widget _buildAvatar(GlobalWinAnnouncement win) {
    final avatar = _WinAvatar(avatarUrl: win.avatarUrl);
    if (win.variant != 'game') return avatar;

    return Transform.translate(offset: const Offset(5, 5), child: avatar);
  }

  @override
  void dispose() {
    _svgaLoadTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    final win = widget.win;
    final userId = win.userId;
    final svgaAsset = GlobalWinSvgaUtil.pickBannerAsset(variant: win.variant);
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
          child: Stack(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                            .map((b) => UserBadgeChip(badge: b))
                                            .toList(),
                                      );
                                    },
                                    loading: () => const SizedBox(height: 14),
                                    error: (_, _) => const SizedBox.shrink(),
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
    final liveRoomId = ref.watch(currentLiveRoomIdProvider);
    final allowTap =
        canOpen &&
        (liveRoomId == null || liveRoomId.toString() != roomId.toString());

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: _bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: banner),
          if (allowTap)
            Positioned(
              left: 72,
              right: 72,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    PattiRoomNavigator.openRoom(context, roomId, ref: ref),
              ),
            ),
        ],
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
