import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/party_screen_config_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/bottom_nav_background_image.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/features/home/presentation/pages/party_screen.dart';
import 'package:sk_live/features/home/presentation/pages/social_discover_screen.dart';
import 'package:sk_live/features/chat/presentation/pages/messages_screen.dart';

import 'package:sk_live/features/auth/presentation/pages/my_profile_screen.dart';
import 'package:sk_live/features/games/presentation/pages/su_games_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/room_invitation_listener.dart';

import 'package:sk_live/core/services/notification_service.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/device_ban_provider.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/room_voice_session_service.dart';
import 'package:sk_live/core/services/dm_realtime_hub.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:sk_live/features/task/presentation/pages/task_screen.dart';
import 'package:sk_live/features/task/presentation/widgets/daily_signin_popup.dart';
import 'package:sk_live/features/task/services/daily_signin_service.dart';
import 'package:sk_live/features/task/data/task_center_provider.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/features/home/services/ranking_room_promo_service.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:sk_live/features/home/presentation/widgets/ranking_room_promo_popup.dart';
import 'package:sk_live/core/services/app_telemetry.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  final Set<String> _builtNavKeys = {'home'};
  bool _dailySignInPrompted = false;

  static Widget _screenForKey(String navKey) {
    switch (navKey) {
      case 'home':
        return const PartyScreen();
      case 'party':
        return const SocialDiscoverScreen();
      case 'game':
        return const SuGamesScreen();
      case 'message':
        return const MessagesScreen();
      case 'my':
        return const MyProfileScreen();
      default:
        return const PartyScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus();
    _cleanupStaleSeatsOnStartup();
    _saveFcmToken();
    unawaited(_registerDevice());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchNavIcons();
      unawaited(_runLaunchPopups());
    });
  }

  Future<void> _registerDevice() async {
    try {
      await ref.read(deviceBanProvider.notifier).registerNow();
    } catch (_) {}
  }

  Future<void> _runLaunchPopups() async {
    if (_dailySignInPrompted || !mounted) return;
    _dailySignInPrompted = true;
    final dailyShown = await _maybeShowDailySignIn();
    if (!mounted) return;
    await _maybeShowRankingRoomPromos(afterDaily: dailyShown);
  }

  Future<bool> _maybeShowDailySignIn() async {
    try {
      final show = await DailySignInService.shouldShowPopup();
      if (!show || !mounted) return false;
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return false;
      final summary = await DailySignInService.fetchSummary();
      if (!mounted || summary == null || summary.days.isEmpty) return false;
      await DailySignInPopup.show(
        context,
        streakDays: summary.streakDay,
        days: summary.days,
        onOpenTasks: () {
          if (!mounted) return;
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TaskScreen()));
        },
      );
      await DailySignInService.markPopupShown();
      if (mounted) {
        ref.invalidate(taskCenterSummaryProvider);
        ref.invalidate(userProfileProvider);
      }
      return true;
    } catch (e) {
      debugPrint('[MainScreen] daily sign-in popup failed: $e');
      return false;
    }
  }

  Future<void> _maybeShowRankingRoomPromos({required bool afterDaily}) async {
    try {
      final show = await RankingRoomPromoService.shouldShowToday();
      if (!show || !mounted) return;

      final promos = await RankingRoomPromoService.loadTopPromos(
        fetchRoomDayRankings: () =>
            ref.read(rankingsProvider(('Room', 'Day')).future),
      );
      if (!mounted || promos.isEmpty) {
        await RankingRoomPromoService.markShownToday();
        return;
      }

      await Future<void>.delayed(
        Duration(milliseconds: afterDaily ? 380 : 700),
      );
      if (!mounted) return;

      for (final promo in promos) {
        if (!mounted) return;
        final entered = await RankingRoomPromoPopup.show(
          context,
          promo: promo,
          onEnter: () async {
            if (!mounted) return;
            final room = await RankingRoomPromoService.fetchRoomMap(
              promo.roomId,
            );
            if (!mounted) return;
            if (room == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room is offline right now')),
              );
              return;
            }
            await openRoomLive(context, room);
          },
        );
        if (entered) break;
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }

      await RankingRoomPromoService.markShownToday();
    } catch (e) {
      debugPrint('[MainScreen] ranking room promos failed: $e');
    }
  }

  void _prefetchNavIcons() {
    if (!mounted) return;
    final items = ref.read(bottomNavConfigProvider).valueOrNull;
    if (items != null) {
      unawaited(BottomNavIconPrefetch.prefetchAll(context, items));
    }
  }

  Future<void> _cleanupStaleSeatsOnStartup() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    await RoomVoiceSessionService.cleanupOrphanedSession(userId);
    if (userId != null) {
      debugPrint(
        '[STARTUP_CLEANUP]: Cleaned orphaned voice session for user: $userId',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        AppTelemetry.logEvent(
          'app_resumed',
          params: {
            'image_cache_count':
                PaintingBinding.instance.imageCache.currentSize,
            'image_cache_bytes':
                PaintingBinding.instance.imageCache.currentSizeBytes,
          },
        ),
      );
      _updateUserStatus();
      unawaited(_registerDevice());
      unawaited(
        ref.read(bottomNavConfigProvider.notifier).checkForUpdatesSilently(),
      );
    } else if (state == AppLifecycleState.detached) {
      unawaited(_forceLeaveActiveVoiceSession());
    }
  }

  Future<void> _forceLeaveActiveVoiceSession() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final minimized = ref.read(minimizedRoomProvider);
    final liveRoomId = ref.read(currentLiveRoomIdProvider);
    final session = ref.read(activeRoomSessionProvider);
    final roomId =
        liveRoomId ??
        minimized?['id']?.toString() ??
        session?['id']?.toString();
    if (roomId == null) return;

    debugPrint('[VOICE] App detached — forcing voice cleanup for room $roomId');
    unawaited(RoomFloatingBubbleService.hideRoomBubble());
    unawaited(RoomLiveScreen.cleanupRoomStatic(roomId, userId));
    clearActiveRoomState(ref);
  }

  Future<void> _updateUserStatus() async {
    if (AppConstants.useDmGateway && AppConstants.useRealtimeGateway) {
      try {
        await DmRealtimeHub.instance.ensureStarted();
        await RoomRealtimeSocket.instance.presencePing();
        debugPrint('[STATUS_DEBUG]: presence ping via gateway');
      } catch (e) {
        debugPrint('[STATUS_DEBUG_ERROR]: presence ping failed: $e');
      }
      return;
    }
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await client
            .from('users')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);
        debugPrint('[STATUS_DEBUG]: Updated last seen for user: $userId');
      } catch (e) {
        debugPrint('[STATUS_DEBUG_ERROR]: Failed to update last seen: $e');
      }
    }
  }

  Future<void> _saveFcmToken() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile != null && profile['id'] != null) {
      await NotificationService.saveTokenToDatabase(profile['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);
    ref.listen(bottomNavConfigProvider, (previous, next) {
      next.whenData((items) {
        if (mounted) {
          unawaited(BottomNavIconPrefetch.prefetchAll(context, items));
        }
      });
    });

    final navConfigAsync = ref.watch(bottomNavConfigProvider);
    final navItems = navConfigAsync.maybeWhen(
      data: (items) => items,
      orElse: () => BottomNavItemModel.defaults(),
    );

    if (selectedIndex >= navItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(bottomNavIndexProvider.notifier).state = 0;
        }
      });
    }

    final safeIndex = selectedIndex.clamp(0, navItems.length - 1);
    final activeNavKey = navItems.isNotEmpty
        ? navItems[safeIndex].navKey
        : 'home';
    if (!_builtNavKeys.contains(activeNavKey)) {
      _builtNavKeys.add(activeNavKey);
    }
    final isImmersiveTab =
        activeNavKey == 'home' ||
        activeNavKey == 'party' ||
        activeNavKey == 'message' ||
        activeNavKey == 'game';

    final screens = navItems.map((item) {
      if (_builtNavKeys.contains(item.navKey)) {
        return _screenForKey(item.navKey);
      }
      return const SizedBox.shrink();
    }).toList();

    return Scaffold(
      extendBody: isImmersiveTab,
      backgroundColor: isImmersiveTab
          ? Colors.transparent
          : AppColors.background,
      body: Container(
        decoration: isImmersiveTab
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFE9DDF5), AppColors.background],
                ),
              ),
        child: RoomInvitationListener(
          child: IndexedStack(index: safeIndex, children: screens),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            elevation: 0,
          ),
          dividerColor: Colors.transparent,
        ),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: _CompactBottomNav(
            currentIndex: safeIndex,
            isImmersiveTab: isImmersiveTab,
            items: navItems,
            onTap: (index) {
              if (index >= 0 && index < navItems.length) {
                _builtNavKeys.add(navItems[index].navKey);
                unawaited(
                  AppTelemetry.logEvent(
                    'tab_selected',
                    params: {'nav_key': navItems[index].navKey},
                  ),
                );
                unawaited(AppTelemetry.setContext(tab: navItems[index].navKey));
              }
              ref.read(bottomNavIndexProvider.notifier).state = index;
            },
          ),
        ),
      ),
    );
  }
}

class _CompactBottomNav extends ConsumerWidget {
  const _CompactBottomNav({
    required this.currentIndex,
    required this.isImmersiveTab,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final bool isImmersiveTab;
  final List<BottomNavItemModel> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final partyConfig =
        ref.watch(partyScreenConfigProvider).valueOrNull ??
        PartyScreenConfig.empty();

    final totalHeight = bottomNavTotalHeight(context);

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height:
                MediaQuery.paddingOf(context).bottom + kAppBottomNavBarHeight,
            child: BottomNavBackgroundImage(config: partyConfig),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: kAppBottomNavBarHeight + kBottomNavIconFloat,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == currentIndex;
                final labelColor = selected
                    ? AppColors.gold
                    : (isImmersiveTab ? Colors.white : AppColors.textSecondary);

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(index),
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: SizedBox(
                        height: kAppBottomNavBarHeight + kBottomNavIconFloat,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -kBottomNavIconFloat),
                              child: SizedBox(
                                height: kBottomNavIconSlotHeight,
                                width: double.infinity,
                                child: Center(
                                  child: selected
                                      ? _NavActiveIcon(
                                          key: ValueKey(
                                            'nav-focus-${item.navKey}',
                                          ),
                                          item: item,
                                        )
                                      : _NavIcon(
                                          item: item,
                                          size: kBottomNavIconSize,
                                        ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                context.navLabel(item.navKey, item.label),
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.0,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: labelColor,
                                  shadows: isImmersiveTab && !selected
                                      ? const [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black45,
                                          ),
                                        ]
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.item, required this.size});

  final BottomNavItemModel item;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (item.iconUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item.versionedIconUrl,
        cacheKey: '${item.navKey}_icon_${item.cacheVersion}',
        width: size,
        height: size,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => _fallbackImage(),
        errorWidget: (_, __, ___) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      item.fallbackAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }
}

class _NavActiveIcon extends StatefulWidget {
  const _NavActiveIcon({super.key, required this.item});

  final BottomNavItemModel item;

  @override
  State<_NavActiveIcon> createState() => _NavActiveIconState();
}

class _NavActiveIconState extends State<_NavActiveIcon>
    with SingleTickerProviderStateMixin {
  static const double _size = kBottomNavActiveIconSize;
  static const double _tiltAngle = -0.14;

  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.42,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 28,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final Widget icon;
    if (item.activeIconUrl != null && item.activeIconUrl!.isNotEmpty) {
      icon = CachedNetworkImage(
        imageUrl: item.versionedActiveIconUrl!,
        cacheKey: '${item.navKey}_active_${item.cacheVersion}',
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => _NavIcon(item: item, size: _size),
        errorWidget: (_, __, ___) => _NavIcon(item: item, size: _size),
      );
    } else {
      icon = _NavIcon(item: item, size: _size);
    }

    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        width: kBottomNavFocusSize,
        height: kBottomNavFocusSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              kBottomNavFocusAsset,
              width: kBottomNavFocusSize,
              height: kBottomNavFocusSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            Transform.rotate(angle: _tiltAngle, child: icon),
          ],
        ),
      ),
    );
  }
}
