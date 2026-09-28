import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/room_admin_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/room_seat_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/cp_proposal_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/buddy_invite_dialog.dart';
import 'package:sk_live/features/wallet/presentation/pages/bill_records_screen.dart';
import 'package:sk_live/features/auth/presentation/pages/reseller_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationListTile extends StatelessWidget {
  const NotificationListTile({super.key, required this.notif});

  final Map<String, dynamic> notif;

  @override
  Widget build(BuildContext context) {
    final bool isRead = notif['is_read'] ?? false;
    final String type = notif['type'] ?? 'info';
    final DateTime date = DateTime.parse(notif['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white.withValues(alpha: 0.9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isRead
                ? Colors.transparent
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: isRead
            ? null
            : Border.all(
                color: AppColors.accent.withValues(alpha: 0.15),
                width: 1,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleTap(context, isRead, type),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: notificationColorsForType(type),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      notificationIconForType(type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notif['title'] ?? 'System Message',
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  fontSize: 16,
                                  color: isRead
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              timeago.format(date),
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif['content'] ?? '',
                          style: TextStyle(
                            color: isRead
                                ? AppColors.textHint
                                : const Color(0xFF757575),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    bool isRead,
    String type,
  ) async {
    if (!isRead) {
      await NotificationDB.markAsRead(notif['id']);
    }

    if (type == 'room_admin_invite') {
      openRoomAdminInviteFromNotification(notif);
    } else if (type == 'buddy_invite') {
      openBuddyInviteFromNotification(notif);
    } else if (type == 'room_seat_invite') {
      openRoomSeatInviteFromNotification(notif);
    } else if (type == 'cp_proposal') {
      openCpProposalFromNotification(notif);
    } else if (type == 'room_reward_box' || type == 'room_invite') {
      final roomId = _metadataRoomId(notif);
      if (roomId != null && context.mounted) {
        context.go('${AppRouter.roomDeepLink}/$roomId');
      }
    } else if (type == 'admin_gift') {
      if (context.mounted) {
        context.push(AppRouter.inventory);
      }
    } else if (type == 'withdrawal_request') {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ResellerScreen(initialTab: 1),
          ),
        );
      }
    } else if (type == 'withdrawal_approved' ||
        type == 'withdrawal_rejected' ||
        type == 'withdrawal_completed') {
      if (context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BillRecordsScreen()));
      }
    } else if (type == 'chat' && notif['metadata'] != null) {
      try {
        final metadata = notif['metadata'] is String
            ? Map<String, dynamic>.from(jsonDecode(notif['metadata']))
            : Map<String, dynamic>.from(notif['metadata']);

        if (context.mounted) {
          context.push(
            AppRouter.chat,
            extra: {
              'conversationId': metadata['conversation_id'],
              'targetUserId': metadata['sender_id'],
              'targetUsername': metadata['sender_name'] ?? 'User',
              'targetAvatar': metadata['sender_avatar'],
            },
          );
        }
      } catch (e) {
        debugPrint('Error parsing notification metadata: $e');
      }
    }
  }

  String? _metadataRoomId(Map<String, dynamic> notif) {
    try {
      final raw = notif['metadata'];
      if (raw == null) return null;
      final metadata = raw is String
          ? Map<String, dynamic>.from(jsonDecode(raw))
          : Map<String, dynamic>.from(raw as Map);
      final id = metadata['room_id']?.toString();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (_) {
      return null;
    }
  }
}

List<Color> notificationColorsForType(String type) {
  switch (type) {
    case 'room_admin_invite':
    case 'room_admin_accepted':
    case 'room_admin_rejected':
      return [Colors.amber, Colors.orange];
    case 'room_seat_invite':
    case 'room_seat_accepted':
    case 'room_seat_rejected':
      return [Colors.green, Colors.teal];
    case 'room_reward_box':
    case 'room_invite':
      return [const Color(0xFFFF6F00), const Color(0xFFFFB300)];
    case 'cp_proposal':
    case 'cp_proposal_accepted':
    case 'cp_proposal_rejected':
      return [Colors.pinkAccent, const Color(0xFFE91E63)];
    case 'buddy_invite':
    case 'buddy_invite_accepted':
    case 'buddy_invite_rejected':
      return [const Color(0xFF4DA3FF), const Color(0xFF2F6BFF)];
    case 'lucky_gift':
      return [const Color(0xFFFF6F00), const Color(0xFFFFD54F)];
    case 'gift':
      return [AppColors.gold, const Color(0xFFFFD54F)];
    case 'admin_gift':
      return [const Color(0xFFFFB300), const Color(0xFFFF6F00)];
    case 'reseller_transfer':
      return [const Color(0xFFFFB300), const Color(0xFFFF8F00)];
    case 'withdrawal_request':
    case 'withdrawal_approved':
    case 'withdrawal_completed':
      return [const Color(0xFF7E69FF), const Color(0xFF5C6BC0)];
    case 'withdrawal_rejected':
      return [const Color(0xFFF44336), const Color(0xFFEF5350)];
    case 'alert':
      return [const Color(0xFFF44336), const Color(0xFFEF5350)];
    case 'success':
      return [const Color(0xFF4CAF50), const Color(0xFF81C784)];
    default:
      return [AppColors.accent, const Color(0xFF9C27B0)];
  }
}

IconData notificationIconForType(String type) {
  switch (type) {
    case 'room_admin_invite':
    case 'room_admin_accepted':
    case 'room_admin_rejected':
      return Icons.admin_panel_settings;
    case 'room_seat_invite':
    case 'room_seat_accepted':
    case 'room_seat_rejected':
      return Icons.chair;
    case 'room_reward_box':
      return Iconsax.gift;
    case 'room_invite':
      return Icons.meeting_room;
    case 'cp_proposal':
    case 'cp_proposal_accepted':
    case 'cp_proposal_rejected':
      return Iconsax.heart;
    case 'buddy_invite':
    case 'buddy_invite_accepted':
    case 'buddy_invite_rejected':
      return Iconsax.people;
    case 'lucky_gift':
      return Iconsax.star;
    case 'gift':
      return Iconsax.gift;
    case 'reseller_transfer':
      return Iconsax.coin;
    case 'withdrawal_request':
    case 'withdrawal_approved':
    case 'withdrawal_rejected':
    case 'withdrawal_completed':
      return Iconsax.wallet;
    case 'alert':
      return Iconsax.danger;
    case 'success':
      return Iconsax.tick_circle;
    default:
      return Iconsax.notification_bing;
  }
}
