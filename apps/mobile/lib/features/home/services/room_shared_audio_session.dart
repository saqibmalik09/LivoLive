class RoomSharedAudioSession {
  const RoomSharedAudioSession({
    required this.isActive,
    required this.audioUrl,
    required this.title,
    required this.status,
    required this.timestamp,
    required this.duration,
    this.volume = 1.0,
    this.startedBy,
    this.startedByName,
    this.updatedAt,
  });

  final bool isActive;
  final String audioUrl;
  final String title;
  final String status;
  final double timestamp;
  final double duration;

  final double volume;
  final String? startedBy;
  final String? startedByName;
  final String? updatedAt;

  bool get isPlaying => status == 'playing';

  RoomSharedAudioSession copyWith({
    bool? isActive,
    String? audioUrl,
    String? title,
    String? status,
    double? timestamp,
    double? duration,
    double? volume,
    String? startedBy,
    String? startedByName,
    String? updatedAt,
  }) {
    return RoomSharedAudioSession(
      isActive: isActive ?? this.isActive,
      audioUrl: audioUrl ?? this.audioUrl,
      title: title ?? this.title,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      startedBy: startedBy ?? this.startedBy,
      startedByName: startedByName ?? this.startedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double normalizeVolume(Object? raw) {
    final value = (raw as num?)?.toDouble();
    if (value == null) return 1.0;
    return value.clamp(0.0, 1.0);
  }

  static RoomSharedAudioSession? fromRoomState(Map<String, dynamic>? state) {
    if (state == null) return null;
    if (state['is_active'] != true) return null;
    final url = state['audio_url']?.toString() ?? '';
    if (url.isEmpty) return null;

    return RoomSharedAudioSession(
      isActive: true,
      audioUrl: url,
      title: state['title']?.toString() ?? 'Audio',
      status: state['status']?.toString() ?? 'paused',
      timestamp: (state['timestamp'] as num?)?.toDouble() ?? 0,
      duration: (state['duration'] as num?)?.toDouble() ?? 0,
      volume: normalizeVolume(state['volume']),
      startedBy: state['started_by']?.toString(),
      startedByName: state['started_by_name']?.toString(),
      updatedAt: state['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toRoomState() {
    return {
      'is_active': isActive,
      'audio_url': audioUrl,
      'title': title,
      'status': status,
      'timestamp': timestamp,
      'duration': duration,
      'volume': volume,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'started_by': startedBy,
      'started_by_name': startedByName,
    };
  }
}
