import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_couple_podium.dart';

class CpEventSquareTab extends ConsumerWidget {
  const CpEventSquareTab({super.key, required this.event});

  final PartyEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftTopAsync = ref.watch(cpEventGiftTopProvider(event.id));
    final weeksAsync = ref.watch(cpEventWeeklySnapshotsProvider(event.id));
    final dateFmt = DateFormat('MM.dd');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          giftTopAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: Colors.pinkAccent),
              ),
            ),
            error: (_, _) => const Text(
              'Could not load gift top.',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No CP gift activity yet. Admin must tag gifts for this event.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                );
              }
              return _GiftTopBoard(items: items.take(5).toList());
            },
          ),
          const SizedBox(height: 20),
          weeksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (weeks) {
              if (weeks.isEmpty) return const SizedBox.shrink();
              return Column(
                children: weeks.map((week) {
                  final start = week.periodStart;
                  final end = week.periodEnd;
                  final range = (start != null && end != null)
                      ? '${dateFmt.format(start.toLocal())} - ${dateFmt.format(end.toLocal())}'
                      : '';
                  final top1 = week.topCouples.isNotEmpty
                      ? week.topCouples[0]
                      : null;
                  final top2 = week.topCouples.length > 1
                      ? week.topCouples[1]
                      : null;
                  final top3 = week.topCouples.length > 2
                      ? week.topCouples[2]
                      : null;

                  if (top1 == null && top2 == null && top3 == null) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CpTop3Board(
                      top1: top1,
                      top2: top2,
                      top3: top3,
                      headerTitle: 'Last week',
                      headerSubtitle: range,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GiftTopBoard extends StatelessWidget {
  const _GiftTopBoard({required this.items});

  final List<CpEventGiftTopItem> items;

  static const List<double> _rowCenters = [0.235, 0.405, 0.575, 0.745, 0.880];
  static const double _aspect = 397 / 600;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width - 24;
    final h = w / _aspect;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(CpEventAssets.topGift, fit: BoxFit.fill),
          ),
          Positioned(
            left: w * 0.25,
            top: h * 0.035,
            width: w * 0.50,
            height: h * 0.07,
            child: const Center(
              child: Text(
                'Gift Top',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),
          for (var i = 0; i < items.length && i < _rowCenters.length; i++)
            _GiftTopSlot(
              boardW: w,
              boardH: h,
              centerY: _rowCenters[i],
              item: items[i],
            ),
        ],
      ),
    );
  }
}

class _GiftTopSlot extends StatelessWidget {
  const _GiftTopSlot({
    required this.boardW,
    required this.boardH,
    required this.centerY,
    required this.item,
  });

  final double boardW;
  final double boardH;
  final double centerY;
  final CpEventGiftTopItem item;

  @override
  Widget build(BuildContext context) {
    final rowH = boardH * 0.12;
    return Positioned(
      left: boardW * 0.08,
      top: boardH * centerY - rowH / 2,
      width: boardW * 0.84,
      height: rowH,
      child: Row(
        children: [
          Expanded(child: _userCell(item.senderAvatar, item.senderName)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.giftImageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: item.giftImageUrl,
                    height: rowH * 0.62,
                    fit: BoxFit.contain,
                    errorWidget: (_, _, _) => Icon(
                      Icons.card_giftcard,
                      color: Colors.white70,
                      size: rowH * 0.45,
                    ),
                  )
                else
                  Icon(
                    Icons.card_giftcard,
                    color: Colors.white70,
                    size: rowH * 0.45,
                  ),
                Text(
                  item.giftName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: rowH * 0.16,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(blurRadius: 2, color: Colors.black54),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _userCell(item.receiverAvatar, item.receiverName)),
        ],
      ),
    );
  }

  Widget _userCell(String? avatar, String name) {
    final size = boardH * 0.068;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.2),
          ),
          child: ClipOval(
            child: avatar != null && avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatar,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: size * 0.5,
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[800],
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: size * 0.5,
                    ),
                  ),
          ),
        ),
        SizedBox(height: size * 0.08),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.32,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
      ],
    );
  }
}
