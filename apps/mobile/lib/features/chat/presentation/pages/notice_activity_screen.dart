import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/notification_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/chat/presentation/widgets/message_flow_background.dart';
import 'package:sk_live/features/chat/presentation/widgets/notification_list_tile.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

enum MessageInboxKind { notice, activity }

class NoticeActivityScreen extends ConsumerStatefulWidget {
  const NoticeActivityScreen({super.key, required this.kind});

  final MessageInboxKind kind;

  @override
  ConsumerState<NoticeActivityScreen> createState() =>
      _NoticeActivityScreenState();
}

class _NoticeActivityScreenState extends ConsumerState<NoticeActivityScreen> {
  bool _markingAllRead = false;

  String _title(BuildContext context) => widget.kind == MessageInboxKind.notice
      ? context.l10n.chat_notice
      : context.l10n.chat_activity;

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> notifications) {
    if (widget.kind == MessageInboxKind.notice) {
      return notifications.where((n) => n['category'] == 'system').toList();
    }
    return notifications
        .where((n) => ['room', 'chat', 'gifts'].contains(n['category']))
        .toList();
  }

  PreferredSizeWidget _buildAppBar(
    AsyncValue<List<Map<String, dynamic>>> notificationsAsync,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _title(context),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        notificationsAsync.maybeWhen(
          data: (list) {
            final filtered = _filter(list);
            final hasUnread = filtered.any((n) => n['is_read'] == false);
            if (!hasUnread) return const SizedBox.shrink();
            return TextButton(
              onPressed: _markingAllRead
                  ? null
                  : () async {
                      setState(() => _markingAllRead = true);
                      final ok = await NotificationDB.markAllAsRead();
                      if (!mounted) return;
                      setState(() => _markingAllRead = false);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.chat_couldNotMarkRead),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: _markingAllRead
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.l10n.chat_markAllRead,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                      ),
                    ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(systemNotificationsProvider);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final title = _title(context);

    return MessageFlowScaffold(
      appBar: _buildAppBar(notificationsAsync),
      body: Column(
        children: [
          SizedBox(height: topInset),
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                final filtered = _filter(notifications);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.kind == MessageInboxKind.notice
                              ? Iconsax.notification_bing
                              : Iconsax.activity,
                          size: 64,
                          color: AppColors.textHint.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No $title',
                          style: TextStyle(
                            color: AppColors.textHint.withValues(alpha: 0.8),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    kHomeTabScrollBottomPadding,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return NotificationListTile(notif: filtered[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => asyncErrorWidget(err),
            ),
          ),
        ],
      ),
    );
  }
}
