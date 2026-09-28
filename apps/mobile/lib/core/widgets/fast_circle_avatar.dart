import 'package:flutter/material.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';

class FastCircleAvatar extends StatelessWidget {
  const FastCircleAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    this.fallback,
    this.backgroundColor = AppColors.primaryUltraLight,
  });

  final double radius;
  final String? imageUrl;
  final Widget? fallback;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(48, 192);
    final child =
        fallback ??
        Icon(Icons.person, color: AppColors.primary, size: radius * 0.9);

    final rawUrl = imageUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: child,
      );
    }

    return ClipOval(
      child: AppNetworkImage(
        imageUrl: rawUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        transformWidth: cachePx,
        transformHeight: cachePx,
        transformResize: 'cover',
        transformQuality: 85,
        memCacheWidth: cachePx,
        memCacheHeight: cachePx,
        maxWidthDiskCache: cachePx * 2,
        maxHeightDiskCache: cachePx * 2,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: backgroundColor,
          alignment: Alignment.center,
          child: child,
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: backgroundColor,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

void precacheChatAvatars(
  BuildContext context,
  Iterable<String?> urls, {
  int limit = 24,
  int decodePx = 128,
}) {
  var n = 0;
  for (final raw in urls) {
    final url = raw?.trim();
    if (url == null || url.isEmpty) continue;
    precacheImage(
      AppNetworkImageProvider(
        url,
        transformWidth: decodePx,
        transformHeight: decodePx,
        maxWidth: decodePx,
        maxHeight: decodePx,
      ),
      context,
    );
    n++;
    if (n >= limit) break;
  }
}
