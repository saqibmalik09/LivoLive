import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/lucky_bag_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LuckyBagRoomOverlay extends ConsumerWidget {
  const LuckyBagRoomOverlay({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bagsAsync = ref.watch(roomLuckyBagsProvider(roomId));
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return bagsAsync.when(
      data: (bags) {
        if (bags.isEmpty) return const SizedBox.shrink();
        final now = DateTime.now().toUtc();
        final visible = bags.where((bag) {
          if (bag.slotsLeft <= 0) return false;
          final expires = bag.expiresAt;
          if (expires != null && !expires.isAfter(now)) return false;
          return true;
        }).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: visible.map((bag) {
                return _LuckyBagChip(
                  bag: bag,
                  canClaim: userId != null && userId != bag.senderId,
                  onClaim: () async {
                    final result = await LuckyBagService.claimBag(bag.id);
                    if (!context.mounted) return;
                    if (result['success'] == true) {
                      ref.invalidate(userProfileProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You got ${result['coins']} coins!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result['message']?.toString() ?? 'Claim failed',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LuckyBagChip extends StatelessWidget {
  const _LuckyBagChip({
    required this.bag,
    required this.canClaim,
    required this.onClaim,
  });

  final LuckyBagActiveBag bag;
  final bool canClaim;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canClaim ? onClaim : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LuckyBagTheme.sendGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: LuckyBagTheme.sendShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.gift, color: AppColors.textOnDark, size: 18),
            const SizedBox(width: 6),
            Text(
              '${bag.scope == 'world' ? 'World' : 'Room'} · ${bag.senderName ?? 'User'} · ${bag.totalCoins}',
              style: const TextStyle(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${bag.slotsLeft} left',
              style: TextStyle(
                color: AppColors.textOnDark.withValues(alpha: 0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
