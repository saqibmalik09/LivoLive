import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:sk_live/features/chat/presentation/pages/feedback_screen.dart';
import 'package:sk_live/features/chat/presentation/pages/notice_activity_screen.dart';

class MessageCategoryIcons extends ConsumerWidget {
  const MessageCategoryIcons({super.key});

  static const _noticeAsset = 'assets/design/message/icon_notice_bell.webp';
  static const _activityAsset =
      'assets/design/message/icon_reward_assistant.webp';
  static const _feedbackAsset = 'assets/chat/feedback.webp';

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / 750;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = scaleOf(context);
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
      padding: EdgeInsets.fromLTRB(24 * s, 41 * s, 24 * s, 24 * s),
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
    final s = MessageCategoryIcons.scaleOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 150 * s,
        child: Column(
          children: [
            SizedBox.square(
              dimension: 100 * s,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(asset, fit: BoxFit.contain),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      left: 61 * s,
                      top: 3 * s,
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: 36 * s,
                          minHeight: 26 * s,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 7 * s),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4797B),
                          borderRadius: BorderRadius.circular(13 * s),
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20 * s,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 12 * s),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 26 * s,
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
