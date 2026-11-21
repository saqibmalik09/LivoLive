import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for every remote image in the app.
///
/// Without this, `cached_network_image` uses its default store: **200 objects**.
/// One discovery page is 16 room covers plus 16 host avatars, and a single room
/// adds seat frames, badges, gift icons and game icons on top. Browsing two
/// pages and entering one room evicted the home banners and covers, so they
/// were re-downloaded on every return to home — which is why the banner and
/// backgrounds "took time" even on a warm app.
///
/// The files are already resized and webp-encoded server side by
/// `SupabaseImageTransform`, so these objects are small; 1500 of them is tens
/// of MB on disk, not hundreds.
class AppImageCache {
  const AppImageCache._();

  /// Deliberately not the default `libCachedImageData` key:
  /// `flutter_cache_manager` expects one manager per key, and
  /// `DefaultCacheManager` already owns that one. A distinct key costs one
  /// re-download per image after this ships, then holds far longer.
  static const String _key = 'sk_live_img_v1';

  static final CacheManager manager = CacheManager(
    Config(
      _key,
      maxNrOfCacheObjects: 1500,
      stalePeriod: const Duration(days: 45),
    ),
  );
}
