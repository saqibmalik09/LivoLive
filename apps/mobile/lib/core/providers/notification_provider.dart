import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'auth_provider.dart';
import 'package:sk_live/core/util/app_constants.dart';

bool _isWinBonusNotificationType(String? type) {
  switch (type) {
    case 'lucky_gift':
    case 'lucky_pro_gift':
    case 'game_win':
      return true;
    default:
      return false;
  }
}

String notificationCategoryForType(String? type) {
  switch (type) {
    case 'chat':
      return 'chat';
    case 'room_admin_invite':
    case 'room_admin_accepted':
    case 'room_admin_rejected':
    case 'room_seat_invite':
    case 'room_seat_accepted':
    case 'room_seat_rejected':
    case 'room_reward_box':
    case 'room_invite':
      return 'room';
    case 'buddy_invite':
    case 'buddy_invite_accepted':
    case 'buddy_invite_rejected':
    case 'cp_proposal':
    case 'cp_proposal_accepted':
    case 'cp_proposal_rejected':
    case 'reseller_transfer':
    case 'admin_gift':
    case 'withdrawal_request':
    case 'withdrawal_approved':
    case 'withdrawal_rejected':
    case 'withdrawal_completed':
      return 'system';
    case 'gift':
    case 'lucky_gift':
    case 'lucky_pro_gift':
      return 'gifts';
    default:
      return 'system';
  }
}

final systemNotificationsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final supabase = Supabase.instance.client;
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.session?.user.id;

  if (userId == null) {
    return Stream.value([]);
  }

  return supabase
      .from('system_notifications')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) {
        return data.where((notif) {
          final target = notif['user_id'];
          return target == null || target == userId;
        }).toList();
      })
      .asyncMap((data) async {
        Set<String> readBroadcastIds = {};
        try {
          final broadcastReads = await supabase
              .from('user_notification_reads')
              .select('notification_id')
              .eq('user_id', userId);
          readBroadcastIds = (broadcastReads as List)
              .map((row) => row['notification_id']?.toString())
              .whereType<String>()
              .toSet();
        } catch (e) {
          debugPrint('[NOTIF_DEBUG]: broadcast read table unavailable: $e');
        }

        return data
            .where((notif) {
              final type = notif['type']?.toString();

              if (!AppConstants.enableWinBonusNotifications &&
                  _isWinBonusNotificationType(type)) {
                return false;
              }

              final isRead = _isNotificationRead(notif, readBroadcastIds);
              if (type == 'chat' && isRead) return false;

              return true;
            })
            .map((notif) {
              final copy = Map<String, dynamic>.from(notif);
              copy['is_read'] = _isNotificationRead(copy, readBroadcastIds);
              copy['category'] = notificationCategoryForType(
                copy['type']?.toString(),
              );
              return copy;
            })
            .toList();
      });
});

bool _isNotificationRead(
  Map<String, dynamic> notif,
  Set<String> readBroadcastIds,
) {
  if (notif['user_id'] == null) {
    return readBroadcastIds.contains(notif['id']?.toString());
  }
  return notif['is_read'] == true;
}

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(systemNotificationsProvider);
  return notificationsAsync.maybeWhen(
    data: (notifications) =>
        notifications.where((n) => n['is_read'] != true).length,
    orElse: () => 0,
  );
});

class NotificationDB {
  static Future<bool> markAsRead(String id) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': id},
      );
      final result = Map<String, dynamic>.from(response as Map);
      return result['success'] == true;
    } catch (e) {
      debugPrint(
        '[NOTIF_DEBUG_ERROR]: markAsRead rpc failed, trying direct update: $e',
      );
      try {
        await Supabase.instance.client
            .from('system_notifications')
            .update({'is_read': true})
            .eq('id', id);
        return true;
      } catch (e2) {
        debugPrint('[NOTIF_DEBUG_ERROR]: markAsRead fallback failed: $e2');
        return false;
      }
    }
  }

  static Future<bool> markAllAsRead() async {
    debugPrint('[NOTIF_DEBUG]: Marking all notifications as read');
    try {
      final response = await Supabase.instance.client.rpc(
        'mark_all_notifications_read',
      );
      final result = Map<String, dynamic>.from(response as Map);
      debugPrint('[NOTIF_DEBUG]: markAllAsRead result: $result');
      return result['success'] == true;
    } catch (e) {
      debugPrint(
        '[NOTIF_DEBUG_ERROR]: markAllAsRead rpc failed, trying direct update: $e',
      );
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return false;
        await Supabase.instance.client
            .from('system_notifications')
            .update({'is_read': true})
            .eq('user_id', userId)
            .eq('is_read', false);
        return true;
      } catch (e2) {
        debugPrint('[NOTIF_DEBUG_ERROR]: markAllAsRead fallback failed: $e2');
        return false;
      }
    }
  }
}
