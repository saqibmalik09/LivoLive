class GlobalWinAnnouncement {
  final String id;
  final String? userId;
  final String username;
  final String? avatarUrl;
  final String sourceLabel;
  final int rewardCoins;
  final int bonusMultiplier;
  final String multiplierTier;
  final String variant;
  final String? roomId;
  final DateTime? createdAt;

  const GlobalWinAnnouncement({
    required this.id,
    this.userId,
    required this.username,
    this.avatarUrl,
    required this.sourceLabel,
    required this.rewardCoins,
    required this.bonusMultiplier,
    required this.multiplierTier,
    required this.variant,
    this.roomId,
    this.createdAt,
  });

  factory GlobalWinAnnouncement.fromJson(Map<String, dynamic> json) {
    final roomRaw =
        json['room_id'] ??
        json['roomId'] ??
        json['source_room_id'] ??
        json['sourceRoomId'];
    return GlobalWinAnnouncement(
      id: json['id']?.toString().isNotEmpty == true
          ? json['id'].toString()
          : (json['event_id']?.toString() ?? ''),
      userId: json['user_id']?.toString(),
      username: json['username']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      sourceLabel: json['source_label']?.toString() ?? 'Lucky Gift',
      rewardCoins: _asInt(json['reward_coins']),
      bonusMultiplier: _asInt(json['bonus_multiplier'], fallback: 1),
      multiplierTier: json['multiplier_tier']?.toString() ?? 'x1',
      variant: json['variant']?.toString() ?? 'lucky',
      roomId: roomRaw?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String get badgeLabel {
    switch (variant) {
      case 'lucky_pro':
        return 'Pro';
      case 'game':
        return sourceLabel.isNotEmpty ? sourceLabel : 'Game';
      default:
        return 'Lucky';
    }
  }

  String get tierLabel =>
      multiplierTier.startsWith('x') ? multiplierTier : 'x$bonusMultiplier';

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
