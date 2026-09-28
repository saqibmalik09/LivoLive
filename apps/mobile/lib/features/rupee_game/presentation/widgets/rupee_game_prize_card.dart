import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/rupee_game_provider.dart';

class RupeeGamePrizeCard extends StatelessWidget {
  const RupeeGamePrizeCard({
    super.key,
    required this.prize,
    required this.entryPriceCoins,
    required this.alreadyEntered,
    required this.onBuy,
    this.isLoading = false,
  });

  final RupeeGamePrize prize;
  final int entryPriceCoins;
  final bool alreadyEntered;
  final VoidCallback onBuy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final comingSoon = prize.comingSoon;
    final canBuy =
        !comingSoon && !alreadyEntered && !prize.isDrawn && !isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (!comingSoon)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFB8E6C8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.star_1,
                        size: 14,
                        color: Color(0xFF2E9E5B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${prize.participantCount} have participated',
                        style: const TextStyle(
                          color: Color(0xFF2E9E5B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (comingSoon)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD9A8)),
                  ),
                  child: const Text(
                    'Coming soon',
                    style: TextStyle(
                      color: Color(0xFFB86E00),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 140,
                  child: prize.imageUrl != null && prize.imageUrl!.isNotEmpty
                      ? GestureDetector(
                          onTap: () =>
                              _openFullScreenImage(context, prize.imageUrl!),
                          child: CachedNetworkImage(
                            imageUrl: prize.imageUrl!,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(
                              Iconsax.gift,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : const Icon(Iconsax.gift, size: 64, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  prize.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (prize.originalValueLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Price ${prize.originalValueLabel}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
                if (prize.isDrawn) ...[
                  const SizedBox(height: 8),
                  Text(
                    prize.drawStatus == 'refunded'
                        ? 'Draw complete · Refunds processed'
                        : 'Winner announced',
                    style: const TextStyle(
                      color: Color(0xFF2E9E5B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canBuy ? onBuy : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: comingSoon
                          ? const Color(0xFFB86E00)
                          : const Color(0xFF2E9E5B),
                      disabledBackgroundColor: comingSoon
                          ? const Color(0xFFB86E00)
                          : Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            comingSoon
                                ? 'Coming soon'
                                : alreadyEntered
                                ? 'Participated'
                                : 'Buy for $entryPriceCoins coin${entryPriceCoins == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          width: MediaQuery.sizeOf(context).width,
                          errorWidget: (_, __, ___) => const Icon(
                            Iconsax.gift,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
