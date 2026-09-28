import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/providers/weekly_star_provider.dart';
import 'package:sk_live/features/home/presentation/pages/weekly_star/weekly_star_assets.dart';

class WeeklyStarGiftsRules extends ConsumerWidget {
  const WeeklyStarGiftsRules({super.key, required this.event});

  final PartyEvent event;

  static const double _aspect = 600 / 527;

  static const List<double> _slotXs = [0.175, 0.392, 0.608, 0.825];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(weeklyStarGiftsProvider(event.id));
    final rules = weeklyStarRulesFromEvent(event);
    final w = MediaQuery.sizeOf(context).width - 24;
    final h = w / _aspect;
    final slotSize = w * 0.14;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(WeeklyStarAssets.rules, fit: BoxFit.fill),
            ),
            Positioned(
              left: w * 0.22,
              top: h * 0.06,
              width: w * 0.56,
              height: h * 0.09,
              child: const Center(
                child: Text(
                  'This Week Gift',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                  ),
                ),
              ),
            ),
            giftsAsync.when(
              data: (gifts) {
                return Stack(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Positioned(
                        left: w * _slotXs[i] - slotSize / 2,
                        top: h * 0.255,
                        width: slotSize,
                        child: _GiftSlot(
                          gift: i < gifts.length ? gifts[i] : null,
                          size: slotSize,
                        ),
                      ),
                  ],
                );
              },
              loading: () => Positioned(
                top: h * 0.32,
                left: 0,
                right: 0,
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Positioned(
              left: w * 0.08,
              right: w * 0.08,
              top: h * 0.48,
              bottom: h * 0.06,
              child: SingleChildScrollView(
                child: Text(
                  rules,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftSlot extends StatelessWidget {
  const _GiftSlot({required this.gift, required this.size});

  final WeeklyStarGiftItem? gift;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: gift != null && gift!.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: gift!.imageUrl,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.card_giftcard, color: Colors.white54),
                )
              : const Icon(
                  Icons.card_giftcard,
                  color: Colors.white38,
                  size: 28,
                ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Color(0xFFFFD54F), size: 11),
            const SizedBox(width: 2),
            Text(
              gift != null ? formatWeeklyStarScore(gift!.points) : '--',
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
