import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';

class PromoBannerCarousel extends StatelessWidget {
  const PromoBannerCarousel({
    super.key,
    required this.banners,
    this.height,
    this.aspectRatio = midFeedAspectRatio,
    this.borderRadius = 16,
    this.backgroundColor,
    this.viewportFraction = 1,
    this.enlargeCenterPage = false,
    this.transformWidth = 960,
    this.transformHeight,
    this.placeholder,
    this.errorBuilder,
    this.onBannerTap,
    this.onPageChanged,
    this.active = true,
    this.gaplessPlayback = false,
  });

  /// Paint slides through the gapless (pinnable) provider: a decoded slide
  /// shows on the first frame, and one still loading shows the background
  /// colour instead of a placeholder flash. Pair with [retainImageGroup].
  final bool gaplessPlayback;

  static const double topAspectRatio = 1280 / 560;

  static const double midFeedAspectRatio = 1080 / 320;

  static double heightForWidth(
    double width, {
    double ratio = midFeedAspectRatio,
    double minH = 96,
    double maxH = 180,
  }) {
    final h = width / ratio;
    return h.clamp(minH, maxH);
  }

  final List<Map<String, dynamic>> banners;
  final double? height;
  final double aspectRatio;
  final double borderRadius;
  final Color? backgroundColor;
  final double viewportFraction;
  final bool enlargeCenterPage;
  final int transformWidth;

  /// Server-side CDN crop height. When null, the render endpoint keeps the
  /// source aspect ratio instead of cropping to [height], so the decode can
  /// be far larger than what is actually painted (see [media_url_util.dart]).
  final int? transformHeight;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, dynamic error)?
  errorBuilder;
  final void Function(Map<String, dynamic> banner)? onBannerTap;

  final ValueChanged<int>? onPageChanged;

  /// Set false to stop autoplay/timers while this carousel is scrolled out
  /// of view or its tab is hidden, without unmounting it.
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final h = height ?? heightForWidth(width, ratio: aspectRatio);
    final canLoop = banners.length > 1;

    return CarouselSlider(
      options: CarouselOptions(
        height: h,
        autoPlay: active && canLoop,
        enlargeCenterPage: enlargeCenterPage,
        aspectRatio: aspectRatio,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: canLoop,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        viewportFraction: viewportFraction,
        onPageChanged: onPageChanged == null
            ? null
            : (index, _) => onPageChanged!(index),
      ),
      items: banners.map((banner) {
        final url = banner['image_url']?.toString() ?? '';
        return Builder(
          builder: (context) {
            final image = ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: ColoredBox(
                color: backgroundColor ?? const Color(0x14000000),
                child: AppNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: h,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  transformWidth: transformWidth,
                  transformHeight: transformHeight,
                  memCacheWidth: transformWidth,
                  memCacheHeight: transformHeight,
                  gaplessPlayback: gaplessPlayback,
                  placeholder:
                      placeholder ??
                      (_, _) => ColoredBox(
                        color: backgroundColor ?? const Color(0x14000000),
                      ),
                  errorWidget:
                      errorBuilder ??
                      (_, _, _) => ColoredBox(
                        color: backgroundColor ?? const Color(0x14000000),
                        child: const Icon(Icons.image_outlined),
                      ),
                ),
              ),
            );

            if (onBannerTap == null) return image;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onBannerTap!(banner),
              child: image,
            );
          },
        );
      }).toList(),
    );
  }
}
