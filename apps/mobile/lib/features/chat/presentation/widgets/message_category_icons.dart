import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/chat/presentation/pages/feedback_screen.dart';
import 'package:sk_live/features/chat/presentation/pages/notice_activity_screen.dart';

class MessageCategoryIcons extends ConsumerWidget {
  const MessageCategoryIcons({super.key});

  static const _noticeAsset = 'assets/chat/notification.webp';
  static const _activityAsset = 'assets/chat/activity.webp';
  static const _feedbackAsset = 'assets/chat/feedback.webp';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications =
        ref.watch(systemNotificationsProvider).valueOrNull ?? [];

    final noticeUnread = notifications.where((n) {
      return n['is_read'] != true && n['category'] == 'system';
    }).length;

    final activityUnread = notifications.where((n) {
      return n['is_read'] != true &&
          ['room', 'chat', 'gifts'].contains(n['category']);
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CategoryItem(
            asset: _noticeAsset,
            label: context.l10n.chat_notice,
            unreadCount: noticeUnread,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NoticeActivityScreen(kind: MessageInboxKind.notice),
                ),
              );
            },
          ),
          _CategoryItem(
            asset: _activityAsset,
            label: context.l10n.chat_activity,
            unreadCount: activityUnread,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NoticeActivityScreen(
                    kind: MessageInboxKind.activity,
                  ),
                ),
              );
            },
          ),
          _CategoryItem(
            asset: _feedbackAsset,
            label: context.l10n.chat_feedback,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.asset,
    required this.label,
    required this.onTap,
    this.unreadCount = 0,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(asset, width: 64, height: 64, fit: BoxFit.contain),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
