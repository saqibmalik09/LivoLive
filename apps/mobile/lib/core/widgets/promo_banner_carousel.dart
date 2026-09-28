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
    this.placeholder,
    this.errorBuilder,
    this.onBannerTap,
  });

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
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, dynamic error)?
  errorBuilder;
  final void Function(Map<String, dynamic> banner)? onBannerTap;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final h = height ?? heightForWidth(width, ratio: aspectRatio);

    return CarouselSlider(
      options: CarouselOptions(
        height: h,
        autoPlay: banners.length > 1,
        enlargeCenterPage: enlargeCenterPage,
        aspectRatio: aspectRatio,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: banners.length > 1,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        viewportFraction: viewportFraction,
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
                  transformWidth: transformWidth,
                  memCacheWidth: transformWidth,
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
