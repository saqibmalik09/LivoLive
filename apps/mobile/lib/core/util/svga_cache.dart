import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sk_live/core/util/media_url_util.dart';

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

  /// One cache key per animation. The gift sheet stores the catalog URL with
  /// the storage host rewritten; room broadcasts carry the raw `svga_url`
  /// from the database. Without this they missed each other's cache, so the
  /// first play for someone else always downloaded again.
  static String normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.startsWith('assets/')) return trimmed;
    return SupabaseImageTransform.rewriteStorageHost(trimmed);
  }

  static void pin(Iterable<String> urls) {
    for (final raw in urls) {
      final url = normalize(raw);
      if (url.isNotEmpty) _pinned.add(url);
    }
  }

  static bool isInMemory(String url) => _memory.containsKey(normalize(url));

  /// The decoded animation if it is in memory, without touching LRU order.
  static MovieEntity? peek(String url) => _memory[normalize(url)];
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
  static Future<MovieEntity> load(String rawUrl, {bool fresh = false}) {
    final url = normalize(rawUrl);
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
    _diskWarmed.clear();
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
    final entity = await _decode(data.buffer.asUint8List());
    _remember(assetPath, entity);
    return entity;
  }

  /// `SVGAParser.decodeFromBuffer` inflates (pure-Dart zlib) and parses the
  /// protobuf on the UI isolate: a 1-3 MB gift froze the room for hundreds of
  /// ms on a cheap phone, right when the gift should appear. Here the inflate
  /// (native zlib) and parse run on a background isolate; only the image
  /// decodes, which are async in the engine, stay on this one.
  static Future<MovieEntity> _decode(Uint8List bytes) async {
    final MovieEntity movie;
    try {
      movie = await Isolate.run(() => _parseOffMain(bytes));
    } catch (e) {
      debugPrint('[svga] background parse failed, decoding inline: $e');
      return SVGAParser.shared.decodeFromBuffer(bytes);
    }
    return _prepareImages(movie);
  }

  /// Mirrors the parser's own steps: inflate, parse, and resolve KEEP shapes
  /// to the previous frame's shapes.
  static MovieEntity _parseOffMain(Uint8List bytes) {
    final movie = MovieEntity.fromBuffer(zlib.decode(bytes));
    for (final sprite in movie.sprites) {
      List<ShapeEntity>? lastShape;
      for (final frame in sprite.frames) {
        if (frame.shapes.isEmpty) continue;
        if (frame.shapes[0].type.name == 'KEEP' && lastShape != null) {
          frame.shapes = lastShape;
        } else {
          lastShape = frame.shapes;
        }
      }
    }
    return movie;
  }

  static Future<MovieEntity> _prepareImages(MovieEntity movie) async {
    final images = movie.images;
    if (images.isNotEmpty) {
      await Future.wait(
        images.entries.map((item) async {
          final value = item.value;
          final data = value is Uint8List ? value : Uint8List.fromList(value);
          if (_isMp3(data)) {
            movie.audiosData[item.key] = data;
            return;
          }
          try {
            movie.bitmapCache[item.key] = await decodeImageFromList(data);
          } catch (e) {
            debugPrint('[svga] image ${item.key} failed to decode: $e');
          }
        }),
      );
    }
    movie.releaseMemory();
    return movie;
  }

  static bool _isMp3(Uint8List data) =>
      data.length >= 3 && data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33;

  static Future<MovieEntity> _load(String url) async {
    File? file;
    try {
      file = File('${(await _dir()).path}/${_keyFor(url)}.svga');
      if (await file.exists()) {
        final entity = await _decode(
          await file.readAsBytes(),
        ).timeout(_decodeTimeout);
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
    final entity = await _decode(bytes).timeout(_decodeTimeout);
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
      final url = normalize(raw);
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

  static final Set<String> _diskWarmed = <String>{};

  /// Downloads `.svga` files to disk only — no decode, so no bitmaps held in
  /// memory. The first send of a gift then reads from disk instead of the
  /// network, which is what made the first play show the PNG and only the
  /// second play show the animation. Once per URL per app session, two at a
  /// time so it never competes with what is on screen.
  static Future<void> warmDisk(Iterable<String> urls, {int limit = 40}) async {
    final queue = <String>[];
    for (final raw in urls) {
      if (queue.length >= limit) break;
      final url = normalize(raw);
      if (url.isEmpty || url.startsWith('assets/')) continue;
      if (_memory.containsKey(url) || _inFlight.containsKey(url)) continue;
      if (!_diskWarmed.add(url)) continue;
      queue.add(url);
    }
    if (queue.isEmpty) return;
    final dir = await _dir();
    const batch = 2;
    for (var i = 0; i < queue.length; i += batch) {
      await Future.wait(
        queue.skip(i).take(batch).map((url) async {
          try {
            final file = File('${dir.path}/${_keyFor(url)}.svga');
            if (await file.exists()) return;
            final bytes = await _download(url);
            if (await file.exists()) return;
            // Write then rename, so a play reading the disk copy at the same
            // moment never decodes a half-written file.
            final partial = File('${file.path}.part');
            await partial.writeAsBytes(bytes, flush: true);
            await partial.rename(file.path);
          } catch (e) {
            _diskWarmed.remove(url);
            debugPrint('[svga] disk warm skipped $url: $e');
          }
        }),
      );
    }
  }

  /// Drops decoded animations but keeps the disk copies. Safe to call under
  /// memory pressure.
  static void evictMemory() => _memory.clear();
}
