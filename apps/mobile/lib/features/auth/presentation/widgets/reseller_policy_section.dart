import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/number_formatter.dart';

final coinSellerPolicyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final client = Supabase.instance.client;

  final settingsRes = await client
      .from('coin_seller_policy_settings')
      .select('coins_per_usd, min_recharge_usd, is_active')
      .eq('id', 1)
      .maybeSingle();

  final tiersRes = await client
      .from('coin_seller_policy_tiers')
      .select(
        'id, usd_amount, basic_coins, bonus_ratio_percent, total_coins, label, '
        'is_active, sort_order, '
        'rewards:coin_seller_policy_rewards('
        'feature_key, label, duration_days, vip_plan_id, shop_item_id, sort_order, '
        'shop_item:shop_item_id(id, name, image_url)'
        ')',
      )
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  final vipRes = await client
      .from('vip_plans')
      .select('id, name, level, image_url, duration_days');

  final vipById = <String, Map<String, dynamic>>{
    for (final row in (vipRes as List))
      row['id'].toString(): Map<String, dynamic>.from(row as Map),
  };

  final tiers = (tiersRes as List).map((raw) {
    final tier = Map<String, dynamic>.from(raw as Map);
    final rewards =
        (tier['rewards'] as List? ?? []).map((r) {
          final reward = Map<String, dynamic>.from(r as Map);
          final shopRaw = reward['shop_item'];
          final shop = shopRaw is List
              ? (shopRaw.isNotEmpty
                    ? Map<String, dynamic>.from(shopRaw.first as Map)
                    : null)
              : shopRaw is Map
              ? Map<String, dynamic>.from(shopRaw)
              : null;

          final vipId = reward['vip_plan_id']?.toString();
          final vip = vipId != null ? vipById[vipId] : null;

          final feature = reward['feature_key']?.toString() ?? '';
          String? imageUrl = shop?['image_url']?.toString();
          imageUrl ??= vip?['image_url']?.toString();

          String label = (reward['label'] as String?)?.trim() ?? '';
          if (label.isEmpty) {
            label =
                shop?['name']?.toString() ??
                vip?['name']?.toString() ??
                feature.toUpperCase();
          }
          if (feature == 'vip' && vip != null) {
            final lv = vip['level'];
            label = 'VIP$lv · ${vip['name']}';
          }

          final days =
              (reward['duration_days'] as num?)?.toInt() ??
              (vip?['duration_days'] as num?)?.toInt() ??
              30;

          return {
            ...reward,
            'display_label': label,
            'display_image_url': imageUrl,
            'display_days': days,
            'shop_item_name': shop?['name'],
            'vip_name': vip?['name'],
            'vip_level': vip?['level'],
          };
        }).toList()..sort((a, b) {
          final sa = (a['sort_order'] as num?)?.toInt() ?? 0;
          final sb = (b['sort_order'] as num?)?.toInt() ?? 0;
          return sa.compareTo(sb);
        });

    return {...tier, 'rewards': rewards};
  }).toList();

  return {'settings': settingsRes, 'tiers': tiers};
});

class ResellerPolicySection extends ConsumerWidget {
  const ResellerPolicySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(coinSellerPolicyProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (policy) {
        final settings = policy['settings'] as Map<String, dynamic>?;
        final tiers = (policy['tiers'] as List).cast<Map<String, dynamic>>();
        if (settings != null && settings['is_active'] == false) {
          return const SizedBox.shrink();
        }
        if (tiers.isEmpty) return const SizedBox.shrink();

        final coinsPerUsd =
            (settings?['coins_per_usd'] as num?)?.toInt() ?? 88000;
        final minUsd =
            (settings?['min_recharge_usd'] as num?)?.toDouble() ?? 500;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _policyHeroCard(coinsPerUsd: coinsPerUsd, minUsd: minUsd),
            const SizedBox(height: 14),
            ...tiers.map(
              (tier) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _tierCard(tier),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _policyHeroCard({required int coinsPerUsd, required double minUsd}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.28),
            AppColors.accent.withValues(alpha: 0.12),
            const Color(0xFF1A1220),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Coin Seller Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Iconsax.box_1,
                  color: AppColors.gold,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Fair · Secure · Transparent. Contact staff to top up seller stock. '
            'Rewards for each package are configured by admin and granted on fulfillment.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('1 USD = ${NumberFormatter.format(coinsPerUsd)} coins'),
              _chip('Min \$${minUsd.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tierCard(Map<String, dynamic> tier) {
    final usd = (tier['usd_amount'] as num?)?.toDouble() ?? 0;
    final basic = (tier['basic_coins'] as num?)?.toInt() ?? 0;
    final total = (tier['total_coins'] as num?)?.toInt() ?? 0;
    final ratio = (tier['bonus_ratio_percent'] as num?)?.toDouble() ?? 100;
    final label = (tier['label'] as String?)?.trim();
    final rewards = (tier['rewards'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1524),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD54F),
                      Color(0xFFFFB300),
                      Color(0xFFE65100),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  label?.isNotEmpty == true
                      ? label!
                      : '\$${usd.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFF1A0F08),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${ratio.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _statRow('Basic coins', NumberFormatter.format(basic)),
          const SizedBox(height: 6),
          _statRow(
            'Total coins',
            NumberFormatter.format(total),
            highlight: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.12)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'Rewards',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rewards.isEmpty)
            Text(
              'No rewards configured yet — admin can attach VIP / Frame / Entrance.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rewards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _rewardTile(rewards[i])),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LayoutBuilder(
              builder: (context, c) {
                return CustomPaint(
                  size: Size(c.maxWidth, 1),
                  painter: _DotsPainter(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                );
              },
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.gold : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: highlight ? 15 : 13,
          ),
        ),
      ],
    );
  }

  Widget _rewardTile(Map<String, dynamic> reward) {
    final days = (reward['display_days'] as num?)?.toInt() ?? 30;
    final label = (reward['display_label'] ?? 'Reward').toString();
    final imageUrl = reward['display_image_url']?.toString();
    final feature = reward['feature_key']?.toString() ?? '';
    final icon = switch (feature) {
      'vip' => Iconsax.crown_1,
      'frame' => Iconsax.user,
      'entrance' => Iconsax.car,
      _ => Iconsax.gift,
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) =>
                        Icon(icon, color: AppColors.primary, size: 24),
                  )
                : Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            '$label\nx $days days',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 9,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 5.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) =>
      oldDelegate.color != color;
}
