class RoomYoutubeSession {
  final String videoId;
  final bool isActive;
  final String status;
  final bool canControl;
  final double startAtSeconds;

  const RoomYoutubeSession({
    required this.videoId,
    required this.isActive,
    required this.status,
    required this.canControl,
    this.startAtSeconds = 0,
  });

  bool get isPlaying => status == 'playing';

  RoomYoutubeSession copyWith({
    String? videoId,
    bool? isActive,
    String? status,
    bool? canControl,
    double? startAtSeconds,
  }) {
    return RoomYoutubeSession(
      videoId: videoId ?? this.videoId,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      canControl: canControl ?? this.canControl,
      startAtSeconds: startAtSeconds ?? this.startAtSeconds,
    );
  }

  static RoomYoutubeSession? fromRoomState(
    Map<String, dynamic>? state, {
    required bool canControl,
  }) {
    if (state == null || state['is_active'] != true) return null;
    final videoId = state['video_id']?.toString() ?? '';
    if (videoId.isEmpty) return null;

    return RoomYoutubeSession(
      videoId: videoId,
      isActive: true,
      status: state['status']?.toString() ?? 'playing',
      canControl: canControl,
      startAtSeconds: (state['timestamp'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toRoomState({double? timestamp}) {
    return {
      'is_active': isActive,
      'video_id': videoId,
      'status': status,
      'timestamp': timestamp ?? startAtSeconds,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
