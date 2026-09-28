import 'package:flutter/material.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_assets.dart';

class VipBadgeTabBar extends StatelessWidget {
  const VipBadgeTabBar({
    super.key,
    required this.planCount,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int planCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: planCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          final level = index + 1;

          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedScale(
              scale: isSelected ? 1.08 : 0.88,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: isSelected ? 1 : 0.45,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: VipLevelTheme.colorsForIndex(
                                index,
                              )[0].withValues(alpha: 0.45),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                          ],
                        )
                      : null,
                  child: _BadgeImage(level: level),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BadgeImage extends StatefulWidget {
  const _BadgeImage({required this.level});

  final int level;

  @override
  State<_BadgeImage> createState() => _BadgeImageState();
}

class _BadgeImageState extends State<_BadgeImage> {
  int _candidateIndex = 0;

  @override
  Widget build(BuildContext context) {
    final candidates = VipAssets.badgeAssetCandidates(widget.level);
    final path = candidates[_candidateIndex.clamp(0, candidates.length - 1)];

    return Image.asset(
      path,
      height: 44,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        if (_candidateIndex < candidates.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _candidateIndex++);
          });
        }
        return const SizedBox(width: 72, height: 44);
      },
    );
  }
}
