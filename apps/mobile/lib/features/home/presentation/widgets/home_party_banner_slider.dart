import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sk_live/core/providers/home_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/widgets/promo_banner_carousel.dart';

class HomePartyBannerSlider extends ConsumerWidget {
  const HomePartyBannerSlider({
    super.key,
    this.placement = 'top',
    this.onBannerTap,
    this.onPageChanged,
    this.active = true,
  });

  final String placement;
  final void Function(Map<String, dynamic> banner)? onBannerTap;

  final ValueChanged<int>? onPageChanged;

  /// Set false to stop banner autoplay while scrolled out of view or the
  /// Home tab is hidden, without unmounting the carousel.
  final bool active;

  static const double refDesignWidth = 750;
  static const double refTopHeight = 200;
  static const double refTopSide = 25;
  static const double refTopRadius = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(bannersProvider(placement));
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = screenW - 16;
    final isTop = placement == 'top';
    final ratio = isTop
        ? PromoBannerCarousel.topAspectRatio
        : PromoBannerCarousel.midFeedAspectRatio;
    final bannerH = isTop
        ? refTopHeight * screenW / refDesignWidth
        : PromoBannerCarousel.heightForWidth(
            contentW,
            ratio: ratio,
            minH: isTop ? 100 : 96,
            maxH: isTop ? 200 : 180,
          );
    final transformW = isTop ? 1280 : 960;
    // Crop server-side to the actual on-screen aspect ratio instead of
    // decoding the source image's full (often much taller) aspect ratio.
    final transformH = (transformW / ratio).round();

    return bannersAsync.when(
      skipLoadingOnReload: true,
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        // Pin every slide decoded (same provider the gapless carousel paints
        // with): leaving for a room and coming back never re-decodes them.
        retainImageGroup(
          'banners:$placement',
          [for (final b in banners) b['image_url']?.toString() ?? ''],
          transformWidth: transformW,
          transformHeight: transformH,
          memCacheWidth: transformW,
          memCacheHeight: transformH,
        );

        return Container(
          margin: EdgeInsets.only(
            top: placement == 'after_rooms' ? 4 : 2,
            bottom: placement == 'after_rooms' ? 8 : 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              isTop ? refTopRadius * screenW / refDesignWidth : 16,
            ),
            boxShadow: isTop ? null : AppColors.cardShadow,
          ),
          child: PromoBannerCarousel(
            banners: banners,
            height: bannerH,
            aspectRatio: ratio,
            borderRadius: isTop ? refTopRadius * screenW / refDesignWidth : 16,
            backgroundColor: isTop
                ? Colors.transparent
                : AppColors.primaryUltraLight,
            transformWidth: transformW,
            transformHeight: transformH,
            active: active,
            gaplessPlayback: true,
            onBannerTap: onBannerTap,
            onPageChanged: onPageChanged,
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
