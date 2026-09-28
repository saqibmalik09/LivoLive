import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';

class CpEventRewardTab extends StatelessWidget {
  const CpEventRewardTab({super.key, required this.event});

  final PartyEvent event;

  @override
  Widget build(BuildContext context) {
    final slots = cpEventRewardSlotsFromEvent(event);
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
              _TopRewardFrame(title: slots.rank1Label, items: slots.rank1Items),
              const SizedBox(height: 14),
            ],
            if (slots.rank2Items.isNotEmpty) ...[
              _TopRewardFrame(title: slots.rank2Label, items: slots.rank2Items),
              const SizedBox(height: 14),
            ],
            if (slots.rank3Items.isNotEmpty) ...[
              _TopRewardFrame(title: slots.rank3Label, items: slots.rank3Items),
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

class _TopRewardFrame extends StatelessWidget {
  const _TopRewardFrame({required this.title, required this.items});

  final String title;
  final List<CpEventRewardItem> items;

  static const double _aspect = 600 / 584;
  static const List<({double x, double y})> _slots = [
    (x: 0.22, y: 0.38),
    (x: 0.50, y: 0.38),
    (x: 0.78, y: 0.38),
    (x: 0.50, y: 0.72),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 24;
    final h = w / _aspect;
    final slotSize = w * 0.22;
    final shown = items.take(4).toList();

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(CpEventAssets.topGiftFrame, fit: BoxFit.fill),
          ),
          Positioned(
            left: w * 0.22,
            top: h * 0.055,
            width: w * 0.56,
            height: h * 0.08,
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),
          for (var i = 0; i < shown.length; i++)
            _slot(
              boardW: w,
              boardH: h,
              centerX: _slots[i].x,
              centerY: _slots[i].y,
              size: slotSize,
              item: shown[i],
            ),
        ],
      ),
    );
  }

  Widget _slot({
    required double boardW,
    required double boardH,
    required double centerX,
    required double centerY,
    required double size,
    required CpEventRewardItem item,
  }) {
    return Positioned(
      left: boardW * centerX - size / 2,
      top: boardH * centerY - size / 2,
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => Icon(
                        Icons.card_giftcard,
                        color: Colors.white70,
                        size: size * 0.35,
                      ),
                    )
                  : Icon(
                      Icons.card_giftcard,
                      color: Colors.white54,
                      size: size * 0.35,
                    ),
            ),
          ),
          if (item.label.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, size * 0.06),
              child: Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.11,
                  height: 1.1,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Reward2Frame extends StatelessWidget {
  const _Reward2Frame({required this.title, required this.items});

  final String title;
  final List<CpEventRewardItem> items;

  static const double _aspect = 600 / 375;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 24;
    final h = w / _aspect;
    final slotSize = w * 0.28;
    final shown = items.take(2).toList();

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(CpEventAssets.reward2, fit: BoxFit.fill),
          ),
          Positioned(
            left: w * 0.22,
            top: h * 0.08,
            width: w * 0.56,
            height: h * 0.12,
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
          if (shown.isNotEmpty)
            _twoSlot(
              boardW: w,
              boardH: h,
              centerX: 0.36,
              size: slotSize,
              item: shown[0],
            ),
          if (shown.length > 1)
            _twoSlot(
              boardW: w,
              boardH: h,
              centerX: 0.64,
              size: slotSize,
              item: shown[1],
            ),
        ],
      ),
    );
  }

  Widget _twoSlot({
    required double boardW,
    required double boardH,
    required double centerX,
    required double size,
    required CpEventRewardItem item,
  }) {
    return Positioned(
      left: boardW * centerX - size / 2,
      top: boardH * 0.52 - size / 2,
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => Icon(
                        Icons.card_giftcard,
                        color: Colors.white70,
                        size: size * 0.35,
                      ),
                    )
                  : Icon(
                      Icons.card_giftcard,
                      color: Colors.white54,
                      size: size * 0.35,
                    ),
            ),
          ),
          if (item.label.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, size * 0.06),
              child: Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.11,
                  height: 1.1,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
