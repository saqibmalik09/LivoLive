import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'room_youtube_player_backend.dart';

class RoomYoutubeAndroidBackend implements RoomYoutubePlayerBackend {
  String? _loadedVideoId;
  MethodChannel? _channel;

  @override
  String? get loadedVideoId => _loadedVideoId;

  void _bindChannel(int viewId) {
    _channel = MethodChannel('com.sklive.app/room_youtube_$viewId');
  }

  @override
  Widget buildPlayer({
    required String videoId,
    required double startAtSeconds,
    required bool autoPlay,
    required bool showControls,
  }) {
    _loadedVideoId = videoId;
    return _AndroidYoutubeSurface(
      key: ValueKey(videoId),
      videoId: videoId,
      startAtSeconds: startAtSeconds,
      autoPlay: autoPlay,
      showControls: showControls,
      onViewCreated: _bindChannel,
    );
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    final channel = _channel;
    if (channel == null) return null;
    try {
      return await channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('RoomYoutubeAndroidBackend.$method error: $e');
      return null;
    }
  }

  @override
  Future<void> play() async => _invoke('play');

  @override
  Future<void> pause() async => _invoke('pause');

  @override
  Future<void> loadVideo(String videoId, double startAtSeconds) async {
    _loadedVideoId = videoId;
    await _invoke('loadVideo', {'videoId': videoId, 'startAt': startAtSeconds});
  }

  @override
  Future<void> seekTo(double seconds) async {
    await _invoke('seekTo', {'seconds': seconds});
  }

  @override
  Future<double> currentTimeSeconds() async {
    final value = await _invoke<num>('getCurrentTime');
    return value?.toDouble() ?? 0;
  }

  @override
  Future<bool> isPlaying() async {
    return await _invoke<bool>('isPlaying') ?? false;
  }

  @override
  void dispose() {
    _channel = null;
    _loadedVideoId = null;
  }
}

class _AndroidYoutubeSurface extends StatelessWidget {
  final String videoId;
  final double startAtSeconds;
  final bool autoPlay;
  final bool showControls;
  final void Function(int viewId) onViewCreated;

  const _AndroidYoutubeSurface({
    super.key,
    required this.videoId,
    required this.startAtSeconds,
    required this.autoPlay,
    required this.showControls,
    required this.onViewCreated,
  });

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'room-youtube-player',
      layoutDirection: TextDirection.ltr,
      creationParams: <String, dynamic>{
        'videoId': videoId,
        'startAt': startAtSeconds,
        'autoPlay': autoPlay,
        'showControls': showControls,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: onViewCreated,
    );
  }
}
