import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/util/room_cover_cache.dart';

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
    this.gaplessPlayback = false,
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

  /// Keeps the decoded frame when this image is rebuilt.
  ///
  /// This cached_network_image version has no gaplessPlayback argument; it
  /// maps the flag to [CachedNetworkImage.useOldImageOnUrlChange]. When the
  /// bitmap is already in the memory cache, the placeholder is skipped.
  final bool gaplessPlayback;

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

    if (gaplessPlayback) {
      final provider = _decodedProvider(
        transformed,
        cacheKey: cacheKey,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: maxWidthDiskCache,
        maxHeightDiskCache: maxHeightDiskCache,
      );
      return Image(
        image: provider,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          if (transformed != rewritten) {
            return CachedNetworkImage(
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
              useOldImageOnUrlChange: true,
              placeholder: placeholder,
              progressIndicatorBuilder: progressIndicatorBuilder,
              errorWidget: errorWidget ?? (c, u, e) => const SizedBox.shrink(),
            );
          }
          return errorWidget?.call(context, transformed, error) ??
              const SizedBox.shrink();
        },
      );
    }

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

/// One discovery page (24) plus the next page (16), with a little slack.
/// Holding listeners stops cached_network_image from re-decoding a cover
/// when its cell is recycled, which is the blurry preview on scroll-back.
const int _roomCoverRetainLimit = 48;

class _RetainedCover {
  _RetainedCover(this.stream, this.listener);

  final ImageStream stream;
  final ImageStreamListener listener;
}

final Map<String, _RetainedCover> _retainedRoomCovers = {};

ImageProvider<Object> _decodedProvider(
  String url, {
  String? cacheKey,
  int? memCacheWidth,
  int? memCacheHeight,
  int? maxWidthDiskCache,
  int? maxHeightDiskCache,
}) {
  final ImageProvider<Object> provider = CachedNetworkImageProvider(
    url,
    cacheKey: cacheKey,
    maxWidth: maxWidthDiskCache,
    maxHeight: maxHeightDiskCache,
  );
  if (memCacheWidth == null && memCacheHeight == null) return provider;
  return ResizeImage(provider, width: memCacheWidth, height: memCacheHeight);
}

/// Decoded room cover at [cacheWidth]. Same key the discovery card paints.
ImageProvider<Object> roomCoverImageProvider(String imageUrl, int cacheWidth) {
  final url = roomCoverCacheKey(imageUrl, cacheWidth);
  return _decodedProvider(
    url,
    cacheKey: url,
    memCacheWidth: cacheWidth,
    memCacheHeight: cacheWidth,
  );
}

/// Keeps [imageUrl] decoded until newer covers push it out of the window.
void retainRoomCover(String imageUrl, int cacheWidth) {
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty || cacheWidth <= 0) return;
  final key = roomCoverCacheKey(trimmed, cacheWidth);
  final existing = _retainedRoomCovers.remove(key);
  if (existing != null) {
    _retainedRoomCovers[key] = existing;
    return;
  }
  final stream = roomCoverImageProvider(
    trimmed,
    cacheWidth,
  ).resolve(const ImageConfiguration());
  final listener = ImageStreamListener((info, _) {
    info.dispose();
  }, onError: (_, _) {});
  stream.addListener(listener);
  _retainedRoomCovers[key] = _RetainedCover(stream, listener);
  while (_retainedRoomCovers.length > _roomCoverRetainLimit) {
    final oldest = _retainedRoomCovers.keys.first;
    final removed = _retainedRoomCovers.remove(oldest);
    if (removed == null) break;
    removed.stream.removeListener(removed.listener);
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
