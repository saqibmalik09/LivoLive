import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/game_star_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';

class GameStarRewardTab extends StatelessWidget {
  const GameStarRewardTab({super.key, required this.event});

  final PartyEvent event;

  @override
  Widget build(BuildContext context) {
    final slots = gameStarRewardSlotsFromEvent(event);
    final hasAny =
        slots.rank1Items.isNotEmpty ||
        slots.rank2Items.isNotEmpty ||
        slots.rank3Items.isNotEmpty ||
        slots.rank4to10Items.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        children: [
          if (!hasAny)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Rewards coming soon. Admin can set Top 1–3 and Top 4~10 rewards.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            )
          else ...[
            if (slots.rank1Items.isNotEmpty) ...[
              _Reward5Frame(title: slots.rank1Label, items: slots.rank1Items),
              const SizedBox(height: 14),
            ],
            if (slots.rank2Items.isNotEmpty) ...[
              _Reward5Frame(title: slots.rank2Label, items: slots.rank2Items),
              const SizedBox(height: 14),
            ],
            if (slots.rank3Items.isNotEmpty) ...[
              _Reward5Frame(title: slots.rank3Label, items: slots.rank3Items),
              const SizedBox(height: 14),
            ],
            if (slots.rank4to10Items.isNotEmpty)
              _Reward2Frame(
                title: slots.rank4to10Label,
                items: slots.rank4to10Items,
              ),
          ],
        ],
      ),
    );
  }
}

class _Reward5Frame extends StatelessWidget {
  const _Reward5Frame({required this.title, required this.items});

  final String title;
  final List<GameStarRewardItem> items;

  static const double _aspect = 496 / 592;
  static const List<(double, double)> _slots = [
    (0.22, 0.32),
    (0.50, 0.32),
    (0.78, 0.32),
    (0.35, 0.62),
    (0.65, 0.62),
  ];

  @override
  Widget build(BuildContext context) {
    return _RewardFrameBase(
      asset: GameStarAssets.reward5,
      aspect: _aspect,
      title: title,
      items: items,
      maxItems: 5,
      slots: _slots,
      slotSizeFrac: 0.18,
    );
  }
}

class _Reward2Frame extends StatelessWidget {
  const _Reward2Frame({required this.title, required this.items});

  final String title;
  final List<GameStarRewardItem> items;

  static const double _aspect = 600 / 437;
  static const List<(double, double)> _slots = [(0.35, 0.48), (0.65, 0.48)];

  @override
  Widget build(BuildContext context) {
    return _RewardFrameBase(
      asset: GameStarAssets.reward2,
      aspect: _aspect,
      title: title,
      items: items,
      maxItems: 2,
      slots: _slots,
      slotSizeFrac: 0.22,
      titleTopFrac: 0.08,
    );
  }
}

class _RewardFrameBase extends StatelessWidget {
  const _RewardFrameBase({
    required this.asset,
    required this.aspect,
    required this.title,
    required this.items,
    required this.maxItems,
    required this.slots,
    required this.slotSizeFrac,
    this.titleTopFrac = 0.035,
  });

  final String asset;
  final double aspect;
  final String title;
  final List<GameStarRewardItem> items;
  final int maxItems;
  final List<(double, double)> slots;
  final double slotSizeFrac;
  final double titleTopFrac;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 24;
    final h = w / aspect;
    final shown = items.take(maxItems).toList();
    final slotSize = w * slotSizeFrac;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(child: Image.asset(asset, fit: BoxFit.fill)),
          Positioned(
            left: w * 0.20,
            top: h * titleTopFrac,
            width: w * 0.60,
            height: h * 0.08,
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),
          for (var i = 0; i < shown.length && i < slots.length; i++)
            Positioned(
              left: w * slots[i].$1 - slotSize / 2,
              top: h * slots[i].$2 - slotSize / 2,
              width: slotSize,
              height: slotSize + 20,
              child: Column(
                children: [
                  SizedBox(
                    width: slotSize,
                    height: slotSize,
                    child: shown[i].imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: shown[i].imageUrl,
                            fit: BoxFit.contain,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.card_giftcard,
                              color: Colors.white54,
                            ),
                          )
                        : const Icon(
                            Icons.card_giftcard,
                            color: Colors.white54,
                          ),
                  ),
                  if (shown[i].label.isNotEmpty)
                    Text(
                      shown[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
