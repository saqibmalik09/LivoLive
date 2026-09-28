import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceAudioEntry {
  const DeviceAudioEntry({
    required this.path,
    required this.name,
    this.size,
    this.durationMs,
  });

  final String path;
  final String name;
  final int? size;
  final int? durationMs;

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'size': size,
    'durationMs': durationMs,
  };

  factory DeviceAudioEntry.fromJson(Map<String, dynamic> json) {
    return DeviceAudioEntry(
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Audio',
      size: (json['size'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceAudioEntry && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

class DeviceAudioLibrary {
  static const _audioExtensions = {
    '.mp3',
    '.m4a',
    '.wav',
    '.aac',
    '.flac',
    '.ogg',
    '.wma',
    '.mp4',
    '.3gp',
  };

  static Future<List<DeviceAudioEntry>> loadAudioFiles() async {
    if (kIsWeb) return [];

    final granted = await _requestPermission();
    if (!granted) return [];

    try {
      if (Platform.isAndroid) {
        return _scanAndroid();
      }
      if (Platform.isIOS) {
        return _scanIos();
      }
      return [];
    } catch (e) {
      debugPrint('[DeviceAudioLibrary] load failed: $e');
      return [];
    }
  }

  static Future<List<DeviceAudioEntry>> _scanAndroid() async {
    final entries = <DeviceAudioEntry>[];
    final seen = <String>{};

    final roots = <Directory>{};

    for (final type in [
      StorageDirectory.music,
      StorageDirectory.downloads,
      StorageDirectory.podcasts,
    ]) {
      final dirs = await getExternalStorageDirectories(type: type);
      if (dirs != null) roots.addAll(dirs);
    }

    roots.addAll([
      Directory('/storage/emulated/0/Music'),
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/DCIM'),
    ]);

    for (final dir in roots) {
      if (!await dir.exists()) continue;
      await _scanDirectory(dir, entries, seen, maxDepth: 4);
    }

    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  static Future<List<DeviceAudioEntry>> _scanIos() async {
    final entries = <DeviceAudioEntry>[];
    final seen = <String>{};

    final doc = await getApplicationDocumentsDirectory();
    await _scanDirectory(doc, entries, seen, maxDepth: 3);

    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  static Future<void> _scanDirectory(
    Directory dir,
    List<DeviceAudioEntry> entries,
    Set<String> seen, {
    int maxDepth = 3,
    int depth = 0,
  }) async {
    if (depth > maxDepth) return;

    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          await _scanDirectory(
            entity,
            entries,
            seen,
            maxDepth: maxDepth,
            depth: depth + 1,
          );
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (!_audioExtensions.contains(ext)) continue;
          if (!seen.add(entity.path)) continue;

          final stat = await entity.stat();
          entries.add(
            DeviceAudioEntry(
              path: entity.path,
              name: p.basename(entity.path),
              size: stat.size,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[DeviceAudioLibrary] skip ${dir.path}: $e');
    }
  }

  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final audio = await Permission.audio.request();
      if (audio.isGranted) return true;
      return (await Permission.storage.request()).isGranted;
    }
    if (Platform.isIOS) {
      return (await Permission.mediaLibrary.request()).isGranted ||
          (await Permission.storage.request()).isGranted;
    }
    return true;
  }

  static Future<List<DeviceAudioEntry>> existingOnly(
    List<DeviceAudioEntry> files,
  ) async {
    final out = <DeviceAudioEntry>[];
    for (final file in files) {
      if (file.path.isEmpty) continue;
      try {
        if (await File(file.path).exists()) out.add(file);
      } catch (_) {}
    }
    return out;
  }
}
