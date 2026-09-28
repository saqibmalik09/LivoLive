import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _GlobalPattiRouteGateState extends ConsumerState<GlobalPattiRouteGate> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_sync);
      _router = router;
      _router?.routerDelegate.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final router = _router;
    if (router == null || !mounted) return;

    final location = router.state.matchedLocation;
    final suppress = AppRouter.suppressGlobalPattiOverlays(location);

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
  Widget build(BuildContext context) => widget.child;
}
