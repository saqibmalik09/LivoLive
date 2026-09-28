import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/services/lucky_bag_world_controller.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_theme.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LuckyBagWorldBanner extends ConsumerStatefulWidget {
  const LuckyBagWorldBanner({
    super.key,
    required this.bag,
    required this.onDismiss,
  });

  final WorldLuckyBagAnnouncement bag;
  final VoidCallback onDismiss;

  @override
  ConsumerState<LuckyBagWorldBanner> createState() =>
      _LuckyBagWorldBannerState();
}

class _LuckyBagWorldBannerState extends ConsumerState<LuckyBagWorldBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _autoDismiss = Timer(const Duration(seconds: 8), _dismiss);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  Future<void> _openRoom() async {
    _autoDismiss?.cancel();
    try {
      final room = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('id', widget.bag.roomId)
          .maybeSingle();
      if (!mounted) return;
      if (room == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Room not found')));
        _dismiss();
        return;
      }
      await openRoomLive(context, Map<String, dynamic>.from(room));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open room')));
      }
    }
    if (mounted) _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _openRoom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LuckyBagTheme.sendGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: LuckyBagTheme.sendShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.textOnDark.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.gift,
                      color: AppColors.textOnDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'World Lucky Bag',
                          style: TextStyle(
                            color: AppColors.textOnDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${widget.bag.senderName ?? 'Someone'} sent ${widget.bag.totalCoins} coins · Tap to claim',
                          style: TextStyle(
                            color: AppColors.textOnDark.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Iconsax.coin, color: AppColors.gold, size: 20),
                  IconButton(
                    onPressed: _dismiss,
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textOnDark.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LuckyBagWorldBroadcastHost extends ConsumerWidget {
  const LuckyBagWorldBroadcastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppress = ref.watch(suppressGlobalPattiProvider);
    if (suppress) return child;

    final state = ref.watch(luckyBagWorldControllerProvider);
    final controller = ref.read(luckyBagWorldControllerProvider.notifier);
    final bag = state.currentBag;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        if (bag != null)
          LuckyBagWorldBanner(
            key: ValueKey(bag.id),
            bag: bag,
            onDismiss: controller.dismissCurrent,
          ),
      ],
    );
  }
}
