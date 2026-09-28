import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../services/device_audio_library.dart';
import '../../services/room_shared_audio_queue_controller.dart';
import '../../services/room_shared_audio_queue_logic.dart';
import '../../services/room_shared_audio_sync_controller.dart';
import 'room_shared_audio_now_playing_card.dart';

class RoomSharedAudioSheet extends StatefulWidget {
  const RoomSharedAudioSheet({
    super.key,
    required this.controller,
    required this.queue,
  });

  final RoomSharedAudioSyncController controller;
  final RoomSharedAudioQueueController queue;

  static Future<void> show(
    BuildContext context, {
    required RoomSharedAudioSyncController controller,
    required RoomSharedAudioQueueController queue,
    String? roomId,
  }) {
    assert(roomId == null || roomId == queue.roomId);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          RoomSharedAudioSheet(controller: controller, queue: queue),
    );
  }

  @override
  State<RoomSharedAudioSheet> createState() => _RoomSharedAudioSheetState();
}

class _RoomSharedAudioSheetState extends State<RoomSharedAudioSheet> {
  RoomSharedAudioSyncController get _sync => widget.controller;
  RoomSharedAudioQueueController get _queue => widget.queue;

  @override
  void initState() {
    super.initState();
    _queue.ensureReady();
  }

  Future<void> _browseMoreAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = <DeviceAudioEntry>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null || path.isEmpty) continue;
      picked.add(
        DeviceAudioEntry(path: path, name: file.name, size: file.size),
      );
    }
    await _queue.importFiles(picked);
  }

  Future<void> _playForRoom(DeviceAudioEntry file) async {
    final error = await _queue.playForRoom(file);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: error.contains('already playing')
              ? Colors.orangeAccent
              : Colors.redAccent,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now playing for room: ${file.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _playQueueAt(int index) async {
    final items = _queue.queue.value;
    if (index < 0 || index >= items.length) return;
    final error = await _queue.playQueueAt(index);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: error.contains('already playing')
              ? Colors.orangeAccent
              : Colors.redAccent,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now playing for room: ${items[index].name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _preview(DeviceAudioEntry file) async {
    await _queue.togglePreview(file);
    final label = _queue.activityLabel.value;
    if (!mounted || label == null || !label.startsWith('Could not preview')) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), backgroundColor: Colors.redAccent),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return '';
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Room Audio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _queue.library,
                              _queue.queue,
                              _queue.libraryLoading,
                            ]),
                            builder: (context, _) {
                              if (_queue.libraryLoading.value) {
                                return const SizedBox.shrink();
                              }
                              final queued = _queue.queue.value.length;
                              return Text(
                                queued > 0
                                    ? '$queued in your queue'
                                    : '${_queue.library.value.length} files on device',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _queue.libraryLoading,
                      builder: (context, loading, _) {
                        return IconButton(
                          onPressed: loading ? null : _queue.loadLibrary,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _queue.library,
                    _queue.queue,
                    _queue.currentIndex,
                    _queue.libraryLoading,
                    _queue.libraryError,
                    _queue.uploading,
                    _queue.uploadingName,
                    _queue.previewingPath,
                    _queue.previewPlaying,
                    _queue.activityLabel,
                    _sync.session,
                  ]),
                  builder: (context, _) {
                    return CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildNowPlayingCard()),
                        SliverToBoxAdapter(child: _buildLockHint()),
                        SliverToBoxAdapter(child: _buildActivityLabel()),
                        SliverToBoxAdapter(child: _buildSelectButton()),
                        ..._buildQueueSlivers(),
                        SliverToBoxAdapter(child: _buildLibraryHeader()),
                        ..._buildLibrarySlivers(),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: MediaQuery.paddingOf(context).bottom + 24,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityLabel() {
    return ValueListenableBuilder<String?>(
      valueListenable: _queue.activityLabel,
      builder: (context, label, _) {
        if (label == null || label.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.cyanAccent.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: ValueListenableBuilder<bool>(
          valueListenable: _queue.uploading,
          builder: (context, uploading, _) {
            return OutlinedButton.icon(
              onPressed: uploading ? null : _browseMoreAudio,
              icon: const Icon(Iconsax.folder_add, size: 18),
              label: const Text('Select from device'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: BorderSide(
                  color: Colors.cyanAccent.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLockHint() {
    return ValueListenableBuilder(
      valueListenable: _sync.session,
      builder: (context, session, _) {
        final locked = session != null && session.isActive;
        if (!locked) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            _sync.canControl
                ? 'Stop the current track to play a different one, or let the queue continue.'
                : 'Audio is playing. Only the person who started it can control or stop it.',
            style: TextStyle(
              color: Colors.orangeAccent.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildQueueSlivers() {
    final items = _queue.queue.value;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 16, 4),
          child: Text(
            'Your queue',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      if (items.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              'Select files once — they stay here, play in order, and you can drag to reorder.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        )
      else
        SliverReorderableList(
          itemCount: items.length,
          onReorderItem: _queue.reorderQueue,
          itemBuilder: (context, index) {
            return _buildQueueTile(items[index], index);
          },
        ),
    ];
  }

  Widget _buildQueueTile(DeviceAudioEntry file, int index) {
    final current = _queue.currentIndex.value == index;
    final session = _sync.session.value;
    final isRoomTrack =
        current && session != null && session.title == file.name;
    final isLoading =
        _queue.uploading.value && _queue.uploadingName.value == file.name;
    final isPreviewing =
        _queue.previewingPath.value == file.path && _queue.previewPlaying.value;
    final nextIdx = RoomSharedAudioQueueLogic.nextIndex(
      currentIndex: _queue.currentIndex.value,
      length: _queue.queue.value.length,
    );
    final subtitle = [
      if (isRoomTrack) session.isPlaying ? 'Playing' : 'Paused',
      if (!isRoomTrack && current) 'Up next',
      if (!isRoomTrack && !current && index == nextIdx) 'Next',
      _formatDuration(file.durationMs),
      _formatSize(file.size),
    ].where((s) => s.isNotEmpty).join(' • ');

    return Material(
      key: ValueKey(file.path),
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: isRoomTrack
              ? Colors.cyanAccent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRoomTrack
                ? Colors.cyanAccent.withValues(alpha: 0.35)
                : Colors.white10,
          ),
        ),
        child: ListTile(
          tileColor: Colors.transparent,
          selectedTileColor: Colors.transparent,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.only(left: 8, right: 4),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle_rounded, color: Colors.white38),
          ),
          title: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Preview',
                onPressed: isLoading ? null : () => _preview(file),
                icon: Icon(
                  isPreviewing
                      ? Icons.stop_circle_outlined
                      : Icons.headphones_rounded,
                  color: isPreviewing ? Colors.orangeAccent : Colors.white70,
                ),
              ),
              IconButton(
                tooltip: 'Play for room',
                onPressed: isLoading ? null : () => _playQueueAt(index),
                icon: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyanAccent,
                        ),
                      )
                    : Icon(
                        Icons.play_circle_fill,
                        color: Colors.cyanAccent,
                        size: 28,
                      ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => _queue.removeFromQueue(index),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 4),
      child: Text(
        'On this device',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Widget> _buildLibrarySlivers() {
    if (_queue.libraryLoading.value) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.cyanAccent),
                SizedBox(height: 12),
                Text(
                  'Loading your audio files...',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_queue.library.value.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.music,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  _queue.libraryError.value ?? 'No audio files found',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _queue.loadLibrary,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final queuedPaths = _queue.queue.value.map((e) => e.path).toSet();
    final files = _queue.library.value
        .where((f) => !queuedPaths.contains(f.path))
        .toList(growable: false);
    if (files.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Text(
              'All selected files are in your queue above.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildLibraryTile(files[index]),
            childCount: files.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildLibraryTile(DeviceAudioEntry file) {
    final isLoading =
        _queue.uploading.value && _queue.uploadingName.value == file.name;
    final inQueue = _queue.queue.value.contains(file);
    final isPreviewing =
        _queue.previewingPath.value == file.path && _queue.previewPlaying.value;
    final canStart = _sync.canAdd && !_queue.uploading.value;
    final subtitle = [
      _formatDuration(file.durationMs),
      _formatSize(file.size),
    ].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.cyanAccent,
                  ),
                )
              : const Icon(Icons.audiotrack_rounded, color: Colors.cyanAccent),
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Preview',
              onPressed: isLoading ? null : () => _preview(file),
              icon: Icon(
                isPreviewing
                    ? Icons.stop_circle_outlined
                    : Icons.headphones_rounded,
                color: isPreviewing ? Colors.orangeAccent : Colors.white70,
              ),
            ),
            IconButton(
              tooltip: inQueue ? 'In queue' : 'Add to queue',
              onPressed: inQueue ? null : () => _queue.addToQueue(file),
              icon: Icon(
                inQueue
                    ? Icons.playlist_add_check_rounded
                    : Icons.playlist_add_rounded,
                color: inQueue ? Colors.cyanAccent : Colors.white70,
              ),
            ),
            IconButton(
              tooltip: 'Play for room',
              onPressed: canStart && !isLoading
                  ? () => _playForRoom(file)
                  : null,
              icon: Icon(
                Icons.play_circle_fill,
                color: canStart ? Colors.cyanAccent : Colors.white24,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingCard() {
    return RoomSharedAudioNowPlayingCard(sync: _sync, queue: _queue);
  }
}
