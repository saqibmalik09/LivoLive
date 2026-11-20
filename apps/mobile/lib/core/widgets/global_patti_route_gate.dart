import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/providers/game_overlay_provider.dart';
import 'package:sk_live/core/providers/global_banners_flag.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/services/big_gift_patti_broadcast_controller.dart';
import 'package:sk_live/core/services/global_win_broadcast_controller.dart';
import 'package:sk_live/core/services/lucky_bag_world_controller.dart';

class GlobalPattiRouteGate extends ConsumerStatefulWidget {
  const GlobalPattiRouteGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GlobalPattiRouteGate> createState() =>
      _GlobalPattiRouteGateState();
}

class _GlobalPattiRouteGateState extends ConsumerState<GlobalPattiRouteGate>
    with WidgetsBindingObserver {
  GoRouter? _router;

  static const Duration _bannerFlagEvery = Duration(minutes: 10);
  Timer? _bannerFlagTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerFlagTimer = Timer.periodic(
      _bannerFlagEvery,
      (_) => _refreshBannerFlag(),
    );
    Future.microtask(_refreshBannerFlag);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshBannerFlag();
  }

  Future<void> _refreshBannerFlag() async {
    if (!mounted) return;
    final enabled = await ref.read(globalBannersFetchProvider)();
    if (!mounted || enabled == null) return;
    final notifier = ref.read(globalBannersEnabledProvider.notifier);
    if (notifier.state != enabled) notifier.state = enabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = ref.read(AppRouter.routerProvider);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_sync);
      _router = router;
      _router?.routerDelegate.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    _bannerFlagTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final router = _router;

    final hasRoute =
        router != null && router.routerDelegate.currentConfiguration.isNotEmpty;
    final suppress =
        !ref.read(globalBannersEnabledProvider) ||
        ref.read(gameOverlayOpenProvider) > 0 ||
        (hasRoute &&
            AppRouter.suppressGlobalPattiOverlays(
              router.state.matchedLocation,
            ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prev = ref.read(suppressGlobalPattiProvider);
      if (prev != suppress) {
        ref.read(suppressGlobalPattiProvider.notifier).state = suppress;
      }
      if (suppress) {
        ref.read(globalWinBroadcastControllerProvider.notifier).clearPlayback();
        ref
            .read(bigGiftPattiBroadcastControllerProvider.notifier)
            .clearPlayback();
        ref.read(luckyBagWorldControllerProvider.notifier).clearPlayback();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(gameOverlayOpenProvider, (_, _) => _sync());
    ref.listen<bool>(globalBannersEnabledProvider, (_, _) => _sync());
    return widget.child;
  }
}
