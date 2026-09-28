import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_assets.dart';

class VipHeroBanner extends StatelessWidget {
  const VipHeroBanner({
    super.key,
    required this.level,
    required this.levelIndex,
    required this.unlockedCount,
    required this.totalCount,
  });

  final int level;
  final int levelIndex;
  final int unlockedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colors = VipLevelTheme.colorsForIndex(levelIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerSize = (constraints.maxHeight - 36).clamp(96.0, 140.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: bannerSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: bannerSize,
                      height: bannerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors[0].withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Image.asset(
                      VipAssets.bannerAsset(level),
                      height: bannerSize * 0.88,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Iconsax.crown_1,
                        size: bannerSize * 0.5,
                        color: colors[0],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.verify,
                      color: Color(0xFFFFD700),
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$unlockedCount/$totalCount Benefits',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
