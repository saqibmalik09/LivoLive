import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sk_live/core/providers/home_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/promo_banner_carousel.dart';

class HomePartyBannerSlider extends ConsumerWidget {
  const HomePartyBannerSlider({
    super.key,
    this.placement = 'top',
    this.onBannerTap,
  });

  final String placement;
  final void Function(Map<String, dynamic> banner)? onBannerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(bannersProvider(placement));
    final contentW = MediaQuery.sizeOf(context).width - 16;
    final isTop = placement == 'top';
    final adminTopH = isTop
        ? ref.watch(homeTopBannerHeightProvider).valueOrNull
        : null;
    final ratio = isTop
        ? PromoBannerCarousel.topAspectRatio
        : PromoBannerCarousel.midFeedAspectRatio;
    final bannerH = isTop && adminTopH != null
        ? adminTopH.toDouble()
        : PromoBannerCarousel.heightForWidth(
            contentW,
            ratio: ratio,
            minH: isTop ? 100 : 96,
            maxH: isTop ? 200 : 180,
          );
    final transformW = isTop ? 1280 : 960;

    return bannersAsync.when(
      skipLoadingOnReload: true,
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.only(
            top: placement == 'after_rooms' ? 4 : 2,
            bottom: placement == 'after_rooms' ? 8 : 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.cardShadow,
          ),
          child: PromoBannerCarousel(
            banners: banners,
            height: bannerH,
            aspectRatio: ratio,
            borderRadius: 16,
            backgroundColor: AppColors.primaryUltraLight,
            transformWidth: transformW,
            onBannerTap: onBannerTap,
            placeholder: (context, url) => _shimmer(bannerH),
            errorBuilder: (context, url, error) => Container(
              color: AppColors.primaryUltraLight,
              alignment: Alignment.center,
              child: const Icon(Iconsax.image, color: AppColors.primary),
            ),
          ),
        );
      },
      loading: () =>
          placement == 'top' ? _shimmer(bannerH) : const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  static Widget _shimmer(double height) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
