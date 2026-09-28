import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/services/global_win_broadcast_controller.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';
import 'package:sk_live/core/widgets/global_win_entrance_overlay.dart';

class GlobalWinBroadcastHost extends ConsumerWidget {
  final Widget child;

  const GlobalWinBroadcastHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConstants.enableGlobalWinSvgaBroadcast) {
      return child;
    }

    final suppress = ref.watch(suppressGlobalPattiProvider);
    if (suppress) return child;

    final broadcastState = ref.watch(globalWinBroadcastControllerProvider);
    final currentWin = broadcastState.currentWin;
    final controller = ref.read(globalWinBroadcastControllerProvider.notifier);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        if (currentWin != null)
          GlobalWinEntranceOverlay(
            key: ValueKey(currentWin.id),
            win: currentWin,
            onFinished: controller.onFinished,
          ),
      ],
    );
  }
}
