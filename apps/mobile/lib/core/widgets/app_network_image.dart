import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/media_url_util.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeOutDuration = const Duration(milliseconds: 200),
    this.placeholderFadeInDuration = Duration.zero,
    this.placeholder,
    this.progressIndicatorBuilder,
    this.errorWidget,
    this.cacheKey,
    this.enableTransform = true,
    this.transformWidth = 600,
    this.transformHeight,
    this.transformQuality = 85,
    this.transformResize = 'cover',
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final Duration placeholderFadeInDuration;
  final Widget Function(BuildContext, String)? placeholder;
  final ProgressIndicatorBuilder? progressIndicatorBuilder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  final String? cacheKey;

  final bool enableTransform;

  final int transformWidth;

  final int? transformHeight;

  final int transformQuality;

  final String transformResize;

  @override
  Widget build(BuildContext context) {
    final rewritten = SupabaseImageTransform.rewriteStorageHost(
      imageUrl.trim(),
    );
    final transformed = enableTransform
        ? (SupabaseImageTransform.url(
                rewritten,
                width: transformWidth,
                height: transformHeight,
                resize: transformResize,
                quality: transformQuality,
              ) ??
              rewritten)
        : rewritten;

    Widget Function(BuildContext, String, dynamic)? onError = errorWidget;
    if (transformed != rewritten) {
      final fallbackError = errorWidget;
      onError = (context, url, error) => CachedNetworkImage(
        imageUrl: rewritten,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: maxWidthDiskCache,
        maxHeightDiskCache: maxHeightDiskCache,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: placeholder,
        progressIndicatorBuilder: progressIndicatorBuilder,
        errorWidget: fallbackError ?? (c, u, e) => const SizedBox.shrink(),
      );
    }

    return CachedNetworkImage(
      imageUrl: transformed,
      cacheKey: cacheKey,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      placeholderFadeInDuration: placeholderFadeInDuration,
      placeholder: placeholder,
      progressIndicatorBuilder: progressIndicatorBuilder,
      errorWidget: onError,
    );
  }
}

CachedNetworkImageProvider AppNetworkImageProvider(
  String imageUrl, {
  int transformWidth = 600,
  int? transformHeight,
  int transformQuality = 85,
  String transformResize = 'cover',
  int? maxWidth,
  int? maxHeight,
}) {
  final url =
      SupabaseImageTransform.url(
        imageUrl,
        width: transformWidth,
        height: transformHeight,
        resize: transformResize,
        quality: transformQuality,
      ) ??
      imageUrl;
  return CachedNetworkImageProvider(
    url,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}
