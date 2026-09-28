class BigGiftPattiAnnouncement {
  const BigGiftPattiAnnouncement({
    required this.id,
    required this.username,
    required this.giftCoins,
    this.userId,
    this.avatarUrl,
    this.giftName,
    this.roomId,
    this.createdAt,
  });

  final String id;
  final String? userId;
  final String username;
  final String? avatarUrl;
  final String? giftName;
  final int giftCoins;
  final String? roomId;
  final DateTime? createdAt;

  factory BigGiftPattiAnnouncement.fromJson(Map<String, dynamic> json) {
    return BigGiftPattiAnnouncement(
      id: json['id']?.toString().isNotEmpty == true
          ? json['id'].toString()
          : (json['event_id']?.toString() ?? ''),
      userId: json['user_id']?.toString(),
      username: json['username']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      giftName: json['gift_name']?.toString(),
      giftCoins: _asInt(json['gift_coins']),
      roomId: json['room_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static int _asInt(dynamic raw, {int fallback = 0}) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
