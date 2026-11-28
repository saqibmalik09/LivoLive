import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:sk_live/core/util/app_image_cache.dart';
import 'package:sk_live/core/util/media_url_util.dart';

/// Disk cache for MP4 gift animations.
///
/// Its own store so a few multi-MB videos never evict the image cache, and
/// bounded so a long session of new gifts cannot fill the phone.
class GiftVideoCache {
  GiftVideoCache._();

  static final CacheManager _manager = CacheManager(
    Config(
      'sk_live_gift_video_v1',
      maxNrOfCacheObjects: 60,
      stalePeriod: const Duration(days: 30),
      fileService: AppImageCache.minFreshFileService(concurrentFetches: 3),
    ),
  );

  static const int _maxKnownPaths = 120;

  /// Files already on disk this session, so readiness can be checked
  /// synchronously when a gift lands.
  static final Map<String, String> _onDisk = <String, String>{};
  static final Map<String, Future<File>> _inFlight = <String, Future<File>>{};
  static final Map<String, int> _durationMs = <String, int>{};

  static String _key(String url) =>
      SupabaseImageTransform.rewriteStorageHost(url.trim());

  static bool isReady(String url) => _onDisk.containsKey(_key(url));

  /// The URL actually fetched (storage host rewritten), for streaming.
  static String resolvedUrl(String url) => _key(url);

  /// The local copy if this session already has it on disk.
  static File? readyFile(String url) {
    final path = _onDisk[_key(url)];
    if (path == null) return null;
    final f = File(path);
    return f.existsSync() ? f : null;
  }

  /// Length learned the first time the video was opened; null until then.
  static int? durationMs(String url) => _durationMs[_key(url)];

  static void rememberDuration(String url, Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return;
    _durationMs[_key(url)] = ms;
    while (_durationMs.length > _maxKnownPaths) {
      _durationMs.remove(_durationMs.keys.first);
    }
  }

  /// The local file for [url], downloading it once; concurrent callers share
  /// one download.
  static Future<File> file(String rawUrl) {
    final url = _key(rawUrl);
    final known = _onDisk[url];
    if (known != null) {
      final f = File(known);
      if (f.existsSync()) return Future<File>.value(f);
      _onDisk.remove(url);
    }
    final pending = _inFlight[url];
    if (pending != null) return pending;
    late final Future<File> future;
    future = _manager
        .getSingleFile(url)
        .then((f) {
          _onDisk[url] = f.path;
          while (_onDisk.length > _maxKnownPaths) {
            _onDisk.remove(_onDisk.keys.first);
          }
          return f;
        })
        .whenComplete(() {
          if (identical(_inFlight[url], future)) _inFlight.remove(url);
        });
    _inFlight[url] = future;
    return future;
  }

  /// Puts videos on disk ahead of the first send. Two at a time, failures
  /// ignored: a warm-up must never surface an error.
  static Future<void> prefetch(Iterable<String> urls, {int limit = 8}) async {
    final queue = <String>[];
    for (final raw in urls) {
      if (queue.length >= limit) break;
      if (!MediaUrlUtil.isVideoUrl(raw)) continue;
      final url = _key(raw);
      if (_onDisk.containsKey(url) || _inFlight.containsKey(url)) continue;
      if (!queue.contains(url)) queue.add(url);
    }
    const batch = 2;
    for (var i = 0; i < queue.length; i += batch) {
      await Future.wait(
        queue.skip(i).take(batch).map(
          (url) => file(url).then<void>((_) {}).catchError((Object e) {
            debugPrint('[gift_video] prefetch skipped $url: $e');
          }),
        ),
      );
    }
  }
}
