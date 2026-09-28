import 'package:flutter/widgets.dart';

abstract class RoomYoutubePlayerBackend {
  Widget buildPlayer({
    required String videoId,
    required double startAtSeconds,
    required bool autoPlay,
    required bool showControls,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> loadVideo(String videoId, double startAtSeconds);
  Future<void> seekTo(double seconds);
  Future<double> currentTimeSeconds();
  Future<bool> isPlaying();
  String? get loadedVideoId;
  void dispose();
}
