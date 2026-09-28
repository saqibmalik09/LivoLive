import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'room_youtube_player_backend.dart';

class RoomYoutubeIframeBackend implements RoomYoutubePlayerBackend {
  YoutubePlayerController? _controller;
  String? _loadedVideoId;

  @override
  String? get loadedVideoId => _loadedVideoId;

  void _attachController(YoutubePlayerController controller, String videoId) {
    _controller = controller;
    _loadedVideoId = videoId;
  }

  @override
  Widget buildPlayer({
    required String videoId,
    required double startAtSeconds,
    required bool autoPlay,
    required bool showControls,
  }) {
    return _IframeYoutubePlayer(
      key: ValueKey(videoId),
      videoId: videoId,
      startAtSeconds: startAtSeconds,
      autoPlay: autoPlay,
      showControls: showControls,
      onControllerReady: _attachController,
    );
  }

  @override
  Future<void> play() async {
    await _controller?.playVideo();
  }

  @override
  Future<void> pause() async {
    await _controller?.pauseVideo();
  }

  @override
  Future<void> loadVideo(String videoId, double startAtSeconds) async {
    _loadedVideoId = videoId;
    await _controller?.loadVideoById(
      videoId: videoId,
      startSeconds: startAtSeconds,
    );
  }

  @override
  Future<void> seekTo(double seconds) async {
    await _controller?.seekTo(seconds: seconds, allowSeekAhead: true);
  }

  @override
  Future<double> currentTimeSeconds() async {
    return _controller?.currentTime ?? 0;
  }

  @override
  Future<bool> isPlaying() async {
    final state = await _controller?.playerState;
    return state == PlayerState.playing;
  }

  @override
  void dispose() {
    _controller?.close();
    _controller = null;
    _loadedVideoId = null;
  }
}

class _IframeYoutubePlayer extends StatefulWidget {
  final String videoId;
  final double startAtSeconds;
  final bool autoPlay;
  final bool showControls;
  final void Function(YoutubePlayerController controller, String videoId)
  onControllerReady;

  const _IframeYoutubePlayer({
    super.key,
    required this.videoId,
    required this.startAtSeconds,
    required this.autoPlay,
    required this.showControls,
    required this.onControllerReady,
  });

  @override
  State<_IframeYoutubePlayer> createState() => _IframeYoutubePlayerState();
}

class _IframeYoutubePlayerState extends State<_IframeYoutubePlayer> {
  late final YoutubePlayerController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        mute: false,
        showControls: widget.showControls,
        enableCaption: false,
        strictRelatedVideos: true,
        playsInline: true,
        showFullscreenButton: false,
        showVideoAnnotations: false,
        videoStateUpdateInterval: 500,
      ),
      key: widget.videoId,
    );
    widget.onControllerReady(_controller, widget.videoId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startPlaybackOnce();
  }

  void _startPlaybackOnce() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (widget.autoPlay) {
        await _controller.loadVideoById(
          videoId: widget.videoId,
          startSeconds: widget.startAtSeconds,
        );
      } else {
        await _controller.cueVideoById(
          videoId: widget.videoId,
          startSeconds: widget.startAtSeconds,
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
      keepAlive: true,
    );
  }
}
