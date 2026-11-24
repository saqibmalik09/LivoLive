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

  /// Storage answers `cache-control: no-cache`, which the cache manager reads
  /// as "expired on arrival": every room entry re-downloaded every avatar,
  /// frame and badge (and re-ran the server-side resize), and those refetches
  /// filled the download slots ahead of the frames that were actually new.
  /// Uploads use fresh timestamped paths, so a day is safe; admin assets
  /// replaced in place show within a day.
  static const Duration _minFreshFor = Duration(days: 1);

  /// The library default is 10 for the whole app. A room entry asks for
  /// seats, frames, badges, gift icons and the background at once.
  static const int _concurrentFetches = 24;

  static final CacheManager manager = CacheManager(
    Config(
      _key,
      maxNrOfCacheObjects: 1500,
      stalePeriod: const Duration(days: 45),
      fileService: _MinFreshFileService(HttpFileService(), _minFreshFor)
        ..concurrentFetches = _concurrentFetches,
    ),
  );
}

class _MinFreshFileService extends FileService {
  _MinFreshFileService(this._inner, this._minFreshFor);

  final FileService _inner;
  final Duration _minFreshFor;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _inner.get(url, headers: headers);
    return _MinFreshResponse(response, DateTime.now().add(_minFreshFor));
  }
}

class _MinFreshResponse implements FileServiceResponse {
  _MinFreshResponse(this._inner, this._floor);

  final FileServiceResponse _inner;
  final DateTime _floor;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  int get statusCode => _inner.statusCode;

  @override
  DateTime get validTill {
    final fromHeaders = _inner.validTill;
    return fromHeaders.isAfter(_floor) ? fromHeaders : _floor;
  }

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;
}
