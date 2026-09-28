import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_audio_library.dart';
import 'room_shared_audio_queue_logic.dart';
import 'room_shared_audio_sync_controller.dart';

class RoomSharedAudioQueueController {
  RoomSharedAudioQueueController({
    required this.roomId,
    required RoomSharedAudioSyncController sync,
  }) : _sync = sync {
    _sync.onNaturalComplete = _handleNaturalComplete;
    _sync.isQueueAdvancing = () => _advancing;
    _previewCompleteSub = _previewPlayer.onPlayerComplete.listen((_) {
      previewingPath.value = null;
      previewPlaying.value = false;
    });
    _livePreviewPlayers.add(_previewPlayer);
  }

  static final Set<AudioPlayer> _livePreviewPlayers = <AudioPlayer>{};

  static Future<void> haltAllPreview() async {
    for (final player in _livePreviewPlayers.toList(growable: false)) {
      try {
        await player.stop();
      } catch (_) {}
    }
  }

  static const _prefsPrefix = 'room_audio_queue_v1_';
  static const _urlCachePrefsPrefix = 'room_audio_url_cache_v2_';

  final String roomId;
  RoomSharedAudioSyncController _sync;

  final ValueNotifier<List<DeviceAudioEntry>> library = ValueNotifier(const []);
  final ValueNotifier<List<DeviceAudioEntry>> queue = ValueNotifier(const []);
  final ValueNotifier<int> currentIndex = ValueNotifier(-1);
  final ValueNotifier<String?> previewingPath = ValueNotifier(null);
  final ValueNotifier<bool> previewPlaying = ValueNotifier(false);
  final ValueNotifier<bool> libraryLoading = ValueNotifier(true);
  final ValueNotifier<String?> libraryError = ValueNotifier(null);
  final ValueNotifier<bool> uploading = ValueNotifier(false);
  final ValueNotifier<String?> uploadingName = ValueNotifier(null);
  final ValueNotifier<String?> activityLabel = ValueNotifier(null);

  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<void>? _previewCompleteSub;

  final Map<String, String> _urlCache = {};
  final Map<String, Future<String?>> _inflightUploads = {};
  bool _urlCacheLoaded = false;

  bool _advancing = false;
  Future<void>? _readyFuture;

  RoomSharedAudioSyncController get sync => _sync;

  void bindSync(RoomSharedAudioSyncController sync) {
    if (!identical(_sync, sync)) {
      _sync.onNaturalComplete = null;
      _sync.isQueueAdvancing = null;
      _sync = sync;
    }
    _sync.onNaturalComplete = _handleNaturalComplete;
    _sync.isQueueAdvancing = () => _advancing;
  }

  Future<void> ensureReady() {
    return _readyFuture ??= _loadInitial();
  }

  Future<void> _loadInitial() async {
    await Future.wait([loadPersistedQueue(), _loadUrlCache(), loadLibrary()]);
  }

  Future<void> loadLibrary() async {
    libraryLoading.value = true;
    libraryError.value = null;
    final files = await DeviceAudioLibrary.loadAudioFiles();
    final merged = <DeviceAudioEntry>[];
    final seen = <String>{};
    for (final file in [...queue.value, ...files]) {
      if (file.path.isEmpty || !seen.add(file.path)) continue;
      merged.add(file);
    }
    library.value = merged;
    libraryLoading.value = false;
    if (merged.isEmpty) {
      libraryError.value = 'No audio found or permission denied';
    }
  }

  Future<void> loadPersistedQueue() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$userId');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final parsed = <DeviceAudioEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final entry = DeviceAudioEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (entry.path.isNotEmpty) parsed.add(entry);
      }
      queue.value = await DeviceAudioLibrary.existingOnly(parsed);
    } catch (e) {
      debugPrint('[RoomAudioQueue] load persisted failed: $e');
    }
  }

  Future<void> _persistQueue() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefsPrefix$userId',
        jsonEncode(queue.value.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[RoomAudioQueue] persist failed: $e');
    }
  }

  void _upsertLibrary(Iterable<DeviceAudioEntry> files) {
    final next = <DeviceAudioEntry>[];
    final seen = <String>{};
    for (final file in [...files, ...library.value]) {
      if (file.path.isEmpty || !seen.add(file.path)) continue;
      next.add(file);
    }
    library.value = next;
    if (next.isNotEmpty) libraryError.value = null;
  }

  Future<void> importFiles(List<DeviceAudioEntry> files) async {
    if (files.isEmpty) return;
    final existing = await DeviceAudioLibrary.existingOnly(files);
    if (existing.isEmpty) return;
    _upsertLibrary(existing);
    final nextQueue = List<DeviceAudioEntry>.from(queue.value);
    for (final file in existing) {
      if (!nextQueue.contains(file)) nextQueue.add(file);
    }
    queue.value = nextQueue;
    await _persistQueue();
  }

  Future<void> addToQueue(DeviceAudioEntry file) async {
    if (queue.value.contains(file)) return;
    queue.value = [...queue.value, file];
    _upsertLibrary([file]);
    await _persistQueue();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final next = List<DeviceAudioEntry>.from(queue.value)..removeAt(index);
    currentIndex.value = RoomSharedAudioQueueLogic.remapIndexAfterRemove(
      removedIndex: index,
      currentIndex: currentIndex.value,
    );
    queue.value = next;
    await _persistQueue();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final result = RoomSharedAudioQueueLogic.reorder(
      items: queue.value,
      oldIndex: oldIndex,
      newIndex: newIndex,
      currentIndex: currentIndex.value,
    );
    queue.value = result.items;
    currentIndex.value = result.currentIndex;
    await _persistQueue();
  }

  Future<void> togglePreview(DeviceAudioEntry file) async {
    if (previewingPath.value == file.path && previewPlaying.value) {
      await stopPreview();
      return;
    }
    try {
      await _previewPlayer.stop();
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer.setSource(DeviceFileSource(file.path));
      await _previewPlayer.resume();
      previewingPath.value = file.path;
      previewPlaying.value = true;
    } catch (e) {
      debugPrint('[RoomAudioQueue] preview failed: $e');
      previewingPath.value = null;
      previewPlaying.value = false;
      activityLabel.value = 'Could not preview ${file.name}';
    }
  }

  void cancelAutoAdvance() {}

  Future<void> stopPreview() async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    previewingPath.value = null;
    previewPlaying.value = false;
  }

  Future<String?> playForRoom(DeviceAudioEntry file) async {
    final qi = queue.value.indexWhere((e) => e.path == file.path);
    if (qi >= 0) currentIndex.value = qi;
    return _playFile(file, allowReplaceOwnTrack: false);
  }

  Future<String?> playQueueAt(int index) async {
    if (index < 0 || index >= queue.value.length) {
      return 'Nothing in the queue to play';
    }
    currentIndex.value = index;
    return _playFile(queue.value[index], allowReplaceOwnTrack: true);
  }

  Future<String?> _playFile(
    DeviceAudioEntry file, {
    required bool allowReplaceOwnTrack,
  }) async {
    if (uploading.value) return 'Already uploading a track';

    final sessionActive = _sync.session.value?.isActive == true;
    if (sessionActive && !_sync.canAdd) {
      final canReplace = allowReplaceOwnTrack && _sync.isUploader;
      if (!canReplace) {
        return 'Room audio is already playing. Ask the person who started it to stop first.';
      }
    }

    await stopPreview();

    final cachedUrl = await _lookupCachedUrl(file);
    final needsUpload = cachedUrl == null;
    if (needsUpload) {
      uploading.value = true;
      uploadingName.value = file.name;
      activityLabel.value = 'Uploading ${file.name}…';
    } else {
      activityLabel.value = 'Playing ${file.name}…';
    }

    try {
      final url = cachedUrl ?? await _ensureUploaded(file);
      if (url == null) return 'Could not upload ${file.name}';

      final durationSec = (file.durationMs ?? 0) / 1000.0;
      if (sessionActive && allowReplaceOwnTrack && _sync.isUploader) {
        await _sync.swapActiveTrack(
          audioUrl: url,
          title: file.name,
          duration: durationSec,
        );
      } else {
        if (!_sync.canAdd) {
          return 'Room audio is already playing. Ask the person who started it to stop first.';
        }
        await _sync.playAudio(
          audioUrl: url,
          title: file.name,
          duration: durationSec,
        );
      }
      activityLabel.value = null;
      return null;
    } catch (e) {
      return 'Failed: $e';
    } finally {
      uploading.value = false;
      uploadingName.value = null;
    }
  }

  Future<void> _ensureUrlCacheLoaded() async {
    if (_urlCacheLoaded) return;
    await _loadUrlCache();
  }

  Future<void> _loadUrlCache() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _urlCacheLoaded = true;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_urlCachePrefsPrefix$userId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final k = key?.toString() ?? '';
            final v = value?.toString() ?? '';
            if (k.isNotEmpty && v.startsWith('http')) {
              _urlCache[k] = v;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[RoomAudioQueue] load url cache failed: $e');
    } finally {
      _urlCacheLoaded = true;
    }
  }

  Future<void> _persistUrlCache() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_urlCachePrefsPrefix$userId',
        jsonEncode(_urlCache),
      );
    } catch (e) {
      debugPrint('[RoomAudioQueue] persist url cache failed: $e');
    }
  }

  Future<String?> _fileCacheKey(DeviceAudioEntry file) async {
    if (file.path.isEmpty) return null;
    try {
      final f = File(file.path);
      if (!await f.exists()) return null;
      final len = file.size ?? await f.length();
      return base64Url
          .encode(utf8.encode('${file.path}|$len'))
          .replaceAll('=', '');
    } catch (_) {
      return base64Url.encode(utf8.encode(file.path)).replaceAll('=', '');
    }
  }

  Future<String?> _lookupCachedUrl(DeviceAudioEntry file) async {
    await _ensureUrlCacheLoaded();
    final byPath = _urlCache['path:${file.path}'];
    if (byPath != null && byPath.startsWith('http')) return byPath;

    final key = await _fileCacheKey(file);
    if (key == null) return null;
    final byKey = _urlCache[key];
    if (byKey != null && byKey.startsWith('http')) {
      _urlCache['path:${file.path}'] = byKey;
      unawaited(_persistUrlCache());
      return byKey;
    }
    return null;
  }

  Future<String?> _ensureUploaded(DeviceAudioEntry file) async {
    final existing = await _lookupCachedUrl(file);
    if (existing != null) return existing;

    final key = await _fileCacheKey(file);
    if (key == null) return null;

    return _inflightUploads.putIfAbsent(key, () async {
      try {
        final url = await _uploadAudio(File(file.path), file.name, key);
        if (url != null) {
          _urlCache[key] = url;
          _urlCache['path:${file.path}'] = url;
          unawaited(_persistUrlCache());
        }
        return url;
      } finally {
        _inflightUploads.remove(key);
      }
    });
  }

  Future<String?> _uploadAudio(
    File file,
    String fileName,
    String cacheKey,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'mp3';
    final objectPath = '$userId/room_audio/by_file/$cacheKey.$ext';

    final storage = Supabase.instance.client.storage.from('chat_assets');
    final publicUrl = storage.getPublicUrl(objectPath);

    try {
      await storage.upload(
        objectPath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
    } catch (e) {
      debugPrint('[RoomAudioQueue] upload note: $e');
      if (publicUrl.isNotEmpty) return publicUrl;
      rethrow;
    }

    return publicUrl;
  }

  void _handleNaturalComplete() {
    unawaited(_advanceAfterComplete());
  }

  int _resolveCurrentQueueIndex() {
    final idx = currentIndex.value;
    if (idx >= 0 && idx < queue.value.length) return idx;

    final session = _sync.session.value;
    if (session == null || !session.isActive) return idx;

    final byTitle = queue.value.indexWhere((e) => e.name == session.title);
    if (byTitle >= 0) return byTitle;

    for (var i = 0; i < queue.value.length; i++) {
      final byPath = _urlCache['path:${queue.value[i].path}'];
      if (byPath != null && byPath == session.audioUrl) return i;
    }
    return idx;
  }

  Future<void> _advanceAfterComplete() async {
    if (_advancing) return;
    if (!_sync.isUploader) return;
    _advancing = true;
    try {
      await _sync.runWithoutNaturalComplete(() async {
        if (uploading.value) return;
        if (_sync.session.value?.isActive != true) return;

        final length = queue.value.length;
        if (length <= 0) {
          if (_sync.isUploader && _sync.session.value?.isActive == true) {
            await _sync.stopAudio(reason: 'queue_empty');
          }
          activityLabel.value = null;
          return;
        }

        final resolved = _resolveCurrentQueueIndex();
        if (resolved >= 0 && resolved != currentIndex.value) {
          currentIndex.value = resolved;
        } else if (resolved < 0) {
          currentIndex.value = 0;
        }

        var next = RoomSharedAudioQueueLogic.nextIndex(
          currentIndex: currentIndex.value,
          length: length,
        );
        var skipped = 0;
        while (next >= 0 && skipped < length) {
          currentIndex.value = next;
          final name = queue.value[next].name;
          activityLabel.value = next == 0
              ? 'Queue restarting: $name'
              : 'Playing next: $name';
          final error = await _playFile(
            queue.value[next],
            allowReplaceOwnTrack: true,
          );
          if (error == null) return;
          debugPrint('[RoomAudioQueue] skip $name: $error');
          activityLabel.value = 'Skipped $name';
          skipped += 1;
          next = RoomSharedAudioQueueLogic.nextIndex(
            currentIndex: next,
            length: length,
          );
        }

        if (length > 0) {
          currentIndex.value = 0;
          activityLabel.value = 'Queue restarting: ${queue.value[0].name}';
          final error = await _playFile(
            queue.value[0],
            allowReplaceOwnTrack: true,
          );
          if (error == null) return;
        }

        if (_sync.isUploader && _sync.session.value?.isActive == true) {
          await _sync.stopAudio(reason: 'queue_all_failed');
        }
        activityLabel.value = null;
      });
    } finally {
      _advancing = false;
    }
  }

  Future<void> skipToNext() async {
    if (!_sync.canControl) return;
    final length = queue.value.length;
    if (length <= 0) return;
    final next = RoomSharedAudioQueueLogic.nextIndex(
      currentIndex: currentIndex.value,
      length: length,
    );
    if (next < 0) return;
    await playQueueAt(next);
  }

  Future<void> dispose() async {
    _sync.onNaturalComplete = null;
    _sync.isQueueAdvancing = null;
    await stopPreview();
    await _previewCompleteSub?.cancel();
    _livePreviewPlayers.remove(_previewPlayer);
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    try {
      await _previewPlayer.release();
    } catch (_) {}
    await _previewPlayer.dispose();
    library.dispose();
    queue.dispose();
    currentIndex.dispose();
    previewingPath.dispose();
    previewPlaying.dispose();
    libraryLoading.dispose();
    libraryError.dispose();
    uploading.dispose();
    uploadingName.dispose();
    activityLabel.dispose();
  }
}
