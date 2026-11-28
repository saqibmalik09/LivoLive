import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:path_provider/path_provider.dart';

/// Caches SVGA animations so a gift does not re-download and re-parse on every
/// play.
///
/// `SVGAParser.decodeFromURL` fetches over the network every single time it is
/// called. Gifts therefore paid a full download plus decode before anything
/// appeared — the animation arriving late, and not at all when the request was
/// slow or failed. Repeat gifts paid it again each time.
///
/// Two layers:
///  * memory — decoded [MovieEntity] objects, so a repeated gift is instant
///  * disk — the raw `.svga` bytes, so common gifts survive an app restart
///
/// Cached entities are shared, so callers must never dispose them.
class SvgaCache {
  SvgaCache._();

  /// Sized to comfortably exceed one screenful. The shop grid shows around a
  /// dozen animated tiles at once (the largest category has 70 items, 50 of
  /// them animated), so a cache of 8 evicted entries that were still on screen
  /// and forced constant re-decoding while scrolling. Decoded animations hold
  /// bitmaps, so this is still bounded — and main.dart drops the whole cache
  /// when the OS reports memory pressure.
  static const int _maxMemoryEntries = 20;

  static const Duration _netStallTimeout = Duration(seconds: 20);
  static const Duration _decodeTimeout = Duration(seconds: 30);

  static final LinkedHashMap<String, MovieEntity> _memory =
      LinkedHashMap<String, MovieEntity>();
  static final Map<String, Future<MovieEntity>> _inFlight =
      <String, Future<MovieEntity>>{};

  static final Set<String> _pinned = <String>{};

  static void pin(Iterable<String> urls) {
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isNotEmpty) _pinned.add(url);
    }
  }

  static bool isInMemory(String url) => _memory.containsKey(url);

  /// The decoded animation if it is in memory, without touching LRU order.
  static MovieEntity? peek(String url) => _memory[url];
  static Directory? _cacheDir;

  /// FNV-1a over the url. Deterministic across runs, so disk entries survive a
  /// restart — String.hashCode is not guaranteed stable between SDK versions.
  static String _keyFor(String url) {
    var hash = 0xcbf29ce484222325;
    for (final unit in url.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static Future<Directory> _dir() async {
    final existing = _cacheDir;
    if (existing != null) return existing;
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/svga_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  static void _remember(String url, MovieEntity entity) {
    // A cached entity outlives the widget that first played it, so it must not
    // be released with that widget's controller. SVGAAnimationController.dispose
    // sets `videoItem = null`, and the setter disposes the outgoing entity when
    // `autorelease` is true (the default) — which freed the bitmaps of an entity
    // still held in this cache. Every later player then received a disposed
    // animation, so effects played once and afterwards flickered or never
    // appeared. Opting out makes the cache, not the player, own the lifetime.
    entity.autorelease = false;
    _memory.remove(url);
    _memory[url] = entity;
    while (_memory.length > _maxMemoryEntries) {
      final victim = _memory.keys.firstWhere(
        (k) => !_pinned.contains(k),
        orElse: () => '',
      );
      if (victim.isEmpty) break;
      _memory.remove(victim);
    }
  }

  /// Loads [url], reusing memory then disk before touching the network.
  ///
  /// Concurrent calls for the same url share one download — several people
  /// sending the same gift at once used to trigger several identical fetches.
  static Future<MovieEntity> load(String url, {bool fresh = false}) {
    final cached = _memory[url];
    if (cached != null) {
      _remember(url, cached); // refresh LRU position
      return Future<MovieEntity>.value(cached);
    }
    final pending = _inFlight[url];
    if (pending != null) {
      if (!fresh) return pending;
      debugPrint('[svga] fresh load for $url (previous one still pending)');
    }

    final override = debugLoaderOverride;
    final Future<MovieEntity> started = override == null
        ? _load(url)
        : override(url).then((entity) {
            _remember(url, entity);
            return entity;
          });
    late final Future<MovieEntity> future;
    future = started.whenComplete(() {
      if (identical(_inFlight[url], future)) _inFlight.remove(url);
    });
    _inFlight[url] = future;
    return future;
  }

  @visibleForTesting
  static Future<MovieEntity> Function(String url)? debugLoaderOverride;

  @visibleForTesting
  static void debugReset() {
    _memory.clear();
    _inFlight.clear();
    _pinned.clear();
  }

  /// Loads a bundled `assets/...` animation, keeping the decoded result.
  ///
  /// Bundled assets never touched this cache, so every play re-ran
  /// `decodeFromBuffer`. Decoding is CPU-bound and slow enough on mid-range
  /// devices that the global-win banner — which gives up after 1.5s, twice —
  /// routinely timed out and skipped its animation entirely. Decoding once per
  /// session removes that stall.
  static Future<MovieEntity> loadAsset(String assetPath) {
    final cached = _memory[assetPath];
    if (cached != null) {
      _remember(assetPath, cached);
      return Future<MovieEntity>.value(cached);
    }
    final pending = _inFlight[assetPath];
    if (pending != null) return pending;

    final future = _loadAsset(assetPath)
        .whenComplete(() => _inFlight.remove(assetPath));
    _inFlight[assetPath] = future;
    return future;
  }

  static Future<MovieEntity> _loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final entity = await SVGAParser.shared.decodeFromBuffer(
      data.buffer.asUint8List(),
    );
    _remember(assetPath, entity);
    return entity;
  }

  static Future<MovieEntity> _load(String url) async {
    File? file;
    try {
      file = File('${(await _dir()).path}/${_keyFor(url)}.svga');
      if (await file.exists()) {
        final entity = await SVGAParser.shared
            .decodeFromBuffer(await file.readAsBytes())
            .timeout(_decodeTimeout);
        _remember(url, entity);
        return entity;
      }
    } catch (e) {
      debugPrint('[svga] disk read failed for $url: $e');
      final bad = file;
      if (bad != null) {
        unawaited(bad.delete().then((_) {}, onError: (Object _) {}));
      }
    }

    final bytes = await _download(url);
    final entity = await SVGAParser.shared
        .decodeFromBuffer(bytes)
        .timeout(_decodeTimeout);
    _remember(url, entity);

    // Persist after decoding, so a corrupt download is never cached.
    if (file != null) {
      unawaited(
        file.writeAsBytes(bytes, flush: false).catchError((Object e) {
          debugPrint('[svga] disk write failed for $url: $e');
          return file!;
        }),
      );
    }
    return entity;
  }

  static Future<Uint8List> _download(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(_netStallTimeout);
      final response = await request.close().timeout(_netStallTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final chunks = <int>[];
      await for (final chunk in response.timeout(_netStallTimeout)) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close(force: true);
    }
  }

  /// Warms the cache for animations that are about to be needed.
  ///
  /// The first play of any animation pays a full download before anything can
  /// be drawn. Short-lived effects — entry animations, win banners — finish
  /// their display window before that arrives, so they appeared to not play at
  /// all the first time and only worked once something had cached them. This
  /// fetches them ahead of time, quietly and off the critical path.
  ///
  /// Failures are ignored on purpose: a warm-up that cannot reach the network
  /// must never surface an error or block anything.
  static Future<void> preload(Iterable<String> urls) async {
    final pending = <String>{};
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      if (_memory.containsKey(url)) continue;
      if (_inFlight.containsKey(url)) continue;
      pending.add(url);
    }
    if (pending.isEmpty) return;

    // A handful at a time, so warming never competes with what is on screen.
    const batch = 3;
    final queue = pending.toList();
    for (var i = 0; i < queue.length; i += batch) {
      final slice = queue.skip(i).take(batch);
      await Future.wait(
        slice.map(
          (url) => load(url).catchError((Object e) {
            debugPrint('[svga] preload skipped $url: $e');
            return MovieEntity();
          }),
        ),
      );
    }
  }

  /// Drops decoded animations but keeps the disk copies. Safe to call under
  /// memory pressure.
  static void evictMemory() => _memory.clear();
}
