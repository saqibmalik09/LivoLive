import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class VipPurchaseBar extends ConsumerWidget {
  const VipPurchaseBar({
    super.key,
    required this.plan,
    required this.onPurchase,
  });

  final VipPlan plan;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userVipProvider);
    final userVipLevel =
        (userAsync.valueOrNull?['vip_level'] as num?)?.toInt() ?? 0;

    final statusText = userVipLevel >= plan.level
        ? 'VIP ${plan.level} active'
        : 'You are not this VIP yet.';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      plan.priceCoins.toString(),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Iconsax.coin, color: AppColors.gold, size: 18),
                    Text(
                      ' / ${plan.durationDays}day',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E7), Color(0xFFFFC9D6)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPurchase,
                borderRadius: BorderRadius.circular(28),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  child: Text(
                    'Buy',
                    style: TextStyle(
                      color: Color(0xFF3D2B1F),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
