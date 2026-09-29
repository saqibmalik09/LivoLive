import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Decoded animations hold bitmaps, so this stays deliberately small.
  static const int _maxMemoryEntries = 8;

  static final LinkedHashMap<String, MovieEntity> _memory =
      LinkedHashMap<String, MovieEntity>();
  static final Map<String, Future<MovieEntity>> _inFlight =
      <String, Future<MovieEntity>>{};
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
    _memory.remove(url);
    _memory[url] = entity;
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  /// Loads [url], reusing memory then disk before touching the network.
  ///
  /// Concurrent calls for the same url share one download — several people
  /// sending the same gift at once used to trigger several identical fetches.
  static Future<MovieEntity> load(String url) {
    final cached = _memory[url];
    if (cached != null) {
      _remember(url, cached); // refresh LRU position
      return Future<MovieEntity>.value(cached);
    }
    final pending = _inFlight[url];
    if (pending != null) return pending;

    final future = _load(url).whenComplete(() => _inFlight.remove(url));
    _inFlight[url] = future;
    return future;
  }

  static Future<MovieEntity> _load(String url) async {
    File? file;
    try {
      file = File('${(await _dir()).path}/${_keyFor(url)}.svga');
      if (await file.exists()) {
        final entity = await SVGAParser.shared.decodeFromBuffer(
          await file.readAsBytes(),
        );
        _remember(url, entity);
        return entity;
      }
    } catch (e) {
      debugPrint('[svga] disk read failed for $url: $e');
    }

    final bytes = await _download(url);
    final entity = await SVGAParser.shared.decodeFromBuffer(bytes);
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
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final chunks = <int>[];
      await for (final chunk in response) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    } finally {
      client.close(force: true);
    }
  }

  /// Drops decoded animations but keeps the disk copies. Safe to call under
  /// memory pressure.
  static void evictMemory() => _memory.clear();
}
