import 'package:uuid/uuid.dart';

import 'package:sk_live/core/models/global_win_announcement.dart';

class RoomWinSyncService {
  RoomWinSyncService._();

  static bool isLuckyWinGiftMessage(Map<String, dynamic> message) {
    if (message['type']?.toString() != 'gift' &&
        message['type']?.toString() != 'lucky_win') {
      return false;
    }
    final meta = _asMap(message['metadata']);
    return meta['lucky_bonus_won'] == true ||
        meta['lucky_pro_bonus_won'] == true;
  }

  static bool isGameWinMessage(Map<String, dynamic> message) {
    if (message['type']?.toString() != 'lucky_win') return false;
    final meta = _asMap(message['metadata']);
    final variant =
        meta['special_variant']?.toString() ??
        meta['variant']?.toString() ??
        '';
    if (variant == 'game') return true;
    return meta['game_slug'] != null || meta['game_name'] != null;
  }

  static GlobalWinAnnouncement? announcementFromGiftMessage(
    Map<String, dynamic> message,
  ) {
    if (!isLuckyWinGiftMessage(message)) return null;

    final meta = _asMap(message['metadata']);
    final isLuckyPro =
        meta['is_lucky_pro_gift'] == true ||
        meta['lucky_pro_bonus_won'] == true;
    final rewardCoins = isLuckyPro
        ? _asInt(meta['lucky_pro_bonus_coins'])
        : _asInt(meta['lucky_bonus_coins']);
    if (rewardCoins <= 0) return null;

    final batchId = meta['animation_batch_id']?.toString();
    final eventId = meta['event_id']?.toString();
    final multiplier = _asInt(meta['bonus_multiplier'], fallback: 1);
    final tier = meta['multiplier_tier']?.toString() ?? 'x$multiplier';

    return GlobalWinAnnouncement(
      id: (batchId != null && batchId.isNotEmpty)
          ? batchId
          : (eventId != null && eventId.isNotEmpty
                ? eventId
                : const Uuid().v4()),
      userId: message['user_id']?.toString(),
      username: meta['sender_username']?.toString() ?? 'User',
      avatarUrl: meta['sender_avatar']?.toString(),
      sourceLabel: meta['gift_name']?.toString() ?? 'Lucky Gift',
      rewardCoins: rewardCoins,
      bonusMultiplier: multiplier,
      multiplierTier: tier,
      variant: isLuckyPro ? 'lucky_pro' : 'lucky',
      roomId: _roomIdFromMessage(message, meta),
      createdAt: DateTime.tryParse(message['created_at']?.toString() ?? ''),
    );
  }

  static GlobalWinAnnouncement? announcementFromGameWinMessage(
    Map<String, dynamic> message,
  ) {
    if (!isGameWinMessage(message)) return null;
    if (isLuckyWinGiftMessage(message)) return null;

    final meta = _asMap(message['metadata']);
    final rewardCoins = _asInt(meta['reward_coins']);
    if (rewardCoins <= 0) return null;

    final eventId = meta['event_id']?.toString() ?? message['id']?.toString();
    final multiplier = _asInt(meta['bonus_multiplier'], fallback: 1);
    final tier = meta['multiplier_tier']?.toString() ?? 'x$multiplier';
    final source =
        meta['source_label']?.toString() ??
        meta['game_name']?.toString() ??
        'Game';

    return GlobalWinAnnouncement(
      id: (eventId != null && eventId.isNotEmpty) ? eventId : const Uuid().v4(),
      userId: message['user_id']?.toString(),
      username: meta['sender_username']?.toString() ?? 'User',
      avatarUrl: meta['sender_avatar']?.toString(),
      sourceLabel: source,
      rewardCoins: rewardCoins,
      bonusMultiplier: multiplier,
      multiplierTier: tier,
      variant: 'game',
      roomId: _roomIdFromMessage(message, meta),
      createdAt: DateTime.tryParse(message['created_at']?.toString() ?? ''),
    );
  }

  static GlobalWinAnnouncement? announcementFromRoomMessage(
    Map<String, dynamic> message,
  ) {
    return announcementFromGiftMessage(message) ??
        announcementFromGameWinMessage(message);
  }

  static String fuzzyDedupeKey(GlobalWinAnnouncement win) {
    final t =
        win.createdAt?.millisecondsSinceEpoch ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
    final bucket = t ~/ 4000;
    return 'win:${win.userId}:${win.rewardCoins}:${win.variant}:$bucket';
  }

  static String? _roomIdFromMessage(
    Map<String, dynamic> message,
    Map<String, dynamic> meta,
  ) {
    final raw =
        message['room_id'] ??
        message['roomId'] ??
        meta['room_id'] ??
        meta['roomId'] ??
        meta['source_room_id'];
    final id = raw?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
