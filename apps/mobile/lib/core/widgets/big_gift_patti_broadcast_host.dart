import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/services/big_gift_patti_broadcast_controller.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/big_gift_patti_overlay.dart';

class BigGiftPattiBroadcastHost extends ConsumerWidget {
  const BigGiftPattiBroadcastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConstants.useRealtimeGateway) {
      return child;
    }

    final suppress = ref.watch(suppressGlobalPattiProvider);
    if (suppress) return child;

    final broadcastState = ref.watch(bigGiftPattiBroadcastControllerProvider);
    final current = broadcastState.current;
    final controller = ref.read(
      bigGiftPattiBroadcastControllerProvider.notifier,
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        if (current != null)
          BigGiftPattiOverlay(
            key: ValueKey(current.id),
            username: current.username,
            avatarUrl: current.avatarUrl,
            giftName: current.giftName,
            giftCoins: current.giftCoins,
            roomId: current.roomId,
            onFinished: controller.onFinished,
          ),
      ],
    );
  }
}
