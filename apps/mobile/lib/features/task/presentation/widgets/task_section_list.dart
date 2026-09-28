import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/task/presentation/widgets/task_theme.dart';

class TaskSectionList extends StatelessWidget {
  const TaskSectionList({
    super.key,
    required this.title,
    required this.tasks,
    required this.claimBusy,
    required this.onClaim,
    required this.onGo,
  });

  final String title;
  final List<Map<String, dynamic>> tasks;
  final bool claimBusy;
  final Future<void> Function(Map<String, dynamic> task) onClaim;
  final void Function(Map<String, dynamic> task) onGo;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: TaskTheme.goldBorderPanel(radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...tasks.map(
              (task) => _TaskRow(
                task: task,
                claimBusy: claimBusy,
                onClaim: onClaim,
                onGo: onGo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.claimBusy,
    required this.onClaim,
    required this.onGo,
  });

  final Map<String, dynamic> task;
  final bool claimBusy;
  final Future<void> Function(Map<String, dynamic> task) onClaim;
  final void Function(Map<String, dynamic> task) onGo;

  @override
  Widget build(BuildContext context) {
    final key = task['key']?.toString() ?? '';
    final title = task['title']?.toString() ?? 'Task';
    final target = (task['target_count'] as num?)?.toInt() ?? 1;
    final progress = (task['current_count'] as num?)?.toInt() ?? 0;
    final rewardAmount = (task['reward_amount'] as num?)?.toInt() ?? 0;
    final isClaimed = task['is_claimed'] == true;
    final isCompleted = task['is_completed'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  TaskTheme.panelLight,
                  TaskTheme.deep.withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(
                color: TaskTheme.gold.withValues(alpha: 0.55),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: TaskTheme.magenta.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(_iconFor(key), color: TaskTheme.goldLight, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (!isClaimed)
                        TextSpan(
                          text: ' ($progress/$target)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: TaskTheme.goldLight,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$rewardAmount',
                      style: const TextStyle(
                        color: TaskTheme.goldBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionChip(
            isClaimed: isClaimed,
            isCompleted: isCompleted,
            busy: claimBusy,
            onClaim: () => onClaim(task),
            onGo: () => onGo(task),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'newbie_room_3m':
      case 'room_active_10m':
        return Iconsax.flash_1;
      case 'newbie_mic_3m':
        return Iconsax.microphone;
      case 'newbie_send_gift':
      case 'spend_coins':
        return Iconsax.gift;
      case 'newbie_follow_3':
        return Iconsax.user_add;
      case 'newbie_upload_3':
      case 'upload_images':
      case 'post_trend_images':
        return Iconsax.gallery;
      case 'newbie_link_email':
        return Iconsax.sms;
      case 'recharge_once':
      case 'recharge_accumulated':
        return Iconsax.wallet_3;
      case 'comment_trends':
        return Iconsax.message;
      default:
        return Iconsax.task_square;
    }
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.isClaimed,
    required this.isCompleted,
    required this.busy,
    required this.onClaim,
    required this.onGo,
  });

  final bool isClaimed;
  final bool isCompleted;
  final bool busy;
  final VoidCallback onClaim;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    if (isClaimed) {
      return Text(
        context.l10n.task_got,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      );
    }

    if (isCompleted) {
      return GestureDetector(
        onTap: busy ? null : onClaim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: TaskTheme.claimButton,
            boxShadow: [
              BoxShadow(
                color: TaskTheme.magenta.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            context.l10n.common_claim,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onGo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.4,
          ),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: Text(
          context.l10n.task_go,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
