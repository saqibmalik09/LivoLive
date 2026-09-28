import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class ProfileCoverCarousel extends StatefulWidget {
  const ProfileCoverCarousel({
    super.key,
    required this.imageUrls,
    this.fallbackUrl,
    this.height = 200,
    this.width,
    this.borderRadius = BorderRadius.zero,
    this.onTap,
    this.memCacheWidth = 720,
    this.dotsOverlay = false,
    this.lightDots = false,
    this.emptyPlaceholder,
  });

  final List<String> imageUrls;
  final String? fallbackUrl;
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final int memCacheWidth;
  final bool dotsOverlay;
  final bool lightDots;
  final Widget? emptyPlaceholder;

  @override
  State<ProfileCoverCarousel> createState() => _ProfileCoverCarouselState();
}

class _ProfileCoverCarouselState extends State<ProfileCoverCarousel> {
  int _currentIndex = 0;

  List<String> get _coverUrls =>
      widget.imageUrls.where((url) => url.isNotEmpty).take(3).toList();

  List<String> get _displayUrls {
    if (_coverUrls.isNotEmpty) return _coverUrls;
    final fallback = widget.fallbackUrl?.trim();
    if (fallback != null && fallback.isNotEmpty) return [fallback];
    return [];
  }

  bool get _isCompact => widget.height <= 96;

  double get _boxWidth => widget.width ?? double.infinity;

  @override
  Widget build(BuildContext context) {
    final urls = _displayUrls;
    if (urls.isEmpty) {
      return SizedBox(
        width: _boxWidth,
        height: widget.height,
        child:
            widget.emptyPlaceholder ??
            Container(
              color: const Color(0xFF1A1A2E),
              child: const Center(
                child: Icon(Iconsax.image, color: Colors.white38, size: 48),
              ),
            ),
      );
    }

    if (urls.length == 1) {
      return SizedBox(
        width: _boxWidth,
        height: widget.height,
        child: _wrapTap(_buildImage(urls.first)),
      );
    }

    if (widget.dotsOverlay) {
      return SizedBox(
        width: _boxWidth,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCarousel(urls),
            Positioned(
              left: 0,
              right: 0,
              bottom: _isCompact ? 4 : 12,
              child: _buildDots(urls.length),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _boxWidth,
          height: widget.height,
          child: _buildCarousel(urls),
        ),
        const SizedBox(height: 8),
        _buildDots(urls.length),
      ],
    );
  }

  Widget _buildCarousel(List<String> urls) {
    return CarouselSlider.builder(
      itemCount: urls.length,
      options: CarouselOptions(
        height: widget.height,
        viewportFraction: 1,
        enlargeCenterPage: false,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 3),
        autoPlayAnimationDuration: const Duration(milliseconds: 700),
        autoPlayCurve: Curves.easeInOut,
        enableInfiniteScroll: true,
        onPageChanged: (index, _) => setState(() => _currentIndex = index),
      ),
      itemBuilder: (context, index, _) {
        return _wrapTap(_buildImage(urls[index]));
      },
    );
  }

  Widget _wrapTap(Widget child) {
    if (widget.onTap == null) return child;
    return GestureDetector(onTap: widget.onTap, child: child);
  }

  Widget _buildImage(String url) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: _boxWidth,
        height: widget.height,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: widget.memCacheWidth,
          placeholder: (_, _) => Container(color: AppColors.primaryUltraLight),
          errorWidget: (_, _, _) => Container(
            color: AppColors.primaryUltraLight,
            child: const Icon(Iconsax.image, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildDots(int count) {
    final inactive = widget.lightDots
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.textHint.withValues(alpha: 0.45);
    final active = widget.lightDots ? Colors.white : AppColors.primary;
    final dotH = _isCompact ? 4.0 : 6.0;
    final activeW = _isCompact ? 10.0 : 16.0;
    final inactiveW = _isCompact ? 4.0 : 6.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: _isCompact ? 2 : 3),
          width: isActive ? activeW : inactiveW,
          height: dotH,
          decoration: BoxDecoration(
            color: isActive ? active : inactive,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

List<String> parseProfileCoverImages(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
  }
  return [];
}
