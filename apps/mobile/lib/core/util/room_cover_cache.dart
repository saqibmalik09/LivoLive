import 'package:flutter/widgets.dart';
import 'package:sk_live/core/util/media_url_util.dart';

/// Pixel size for a party-grid cover.
///
/// Matches the home room card (design width 750, side 28, gap 13) and is the
/// same integer with or without a [BuildContext], so prewarm and the card
/// request one Supabase render URL. A second width is what shows up as a
/// blurry preview that then snaps to the full cover.
int roomCoverCacheWidth([BuildContext? context]) {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  double screenW;
  double dpr;
  if (context != null && MediaQuery.sizeOf(context).width > 0) {
    screenW = MediaQuery.sizeOf(context).width;
    dpr = MediaQuery.devicePixelRatioOf(context);
  } else if (views.isEmpty) {
    screenW = 360;
    dpr = 2;
  } else {
    dpr = views.first.devicePixelRatio;
    screenW = views.first.physicalSize.width / dpr;
  }
  if (dpr <= 0) dpr = 2;
  const design = 750.0;
  final s = screenW <= 0 ? 1.0 : screenW / design;
  final logicalCardW = (screenW - (28 * 2 + 13) * s) / 2;
  if (logicalCardW <= 0) return 200;
  final px = (logicalCardW * dpr).round().clamp(200, 480);
  // Bucket so a 1px layout difference does not change the render URL.
  final bucket = (px ~/ 16) * 16;
  return bucket < 200 ? 200 : bucket;
}

/// Disk and memory key for [url] at the pinned cover size.
///
/// This is the transformed URL. Widget recreation with the same cover then
/// hits the image already decoded, instead of looking like a new download.
String roomCoverCacheKey(String url, int cacheWidth) {
  final trimmed = url.trim();
  return SupabaseImageTransform.url(
        trimmed,
        width: cacheWidth,
        height: cacheWidth,
        resize: 'cover',
        quality: 85,
      ) ??
      SupabaseImageTransform.rewriteStorageHost(trimmed);
}
