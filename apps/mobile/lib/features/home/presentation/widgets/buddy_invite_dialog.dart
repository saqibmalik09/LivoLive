import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/buddy_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/util/number_formatter.dart';

Future<void> openBuddyInviteAcceptScreen(
  BuildContext? context, {
  String? invitationId,
  Map<String, dynamic>? invitation,
}) async {
  final ctx = context ?? AppRouter.navigatorKey.currentContext;
  if (ctx == null) return;

  Map<String, dynamic>? invite = invitation;
  if (invite == null && invitationId != null) {
    invite = await BuddyActions.fetchPendingInvitation(invitationId);
  }

  if (invite == null) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Invitation expired or already handled'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return;
  }

  if (!ctx.mounted) return;

  final inviter = invite['inviter'] as Map<String, dynamic>?;
  final inviterName = inviter?['username'] ?? 'Someone';
  final tier =
      BuddyTier.tryParse(invite['tier']?.toString()) ?? BuddyTier.friend;
  final id = invite['id']?.toString();

  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '${tier.label} Invitation',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        '$inviterName invited you to become their ${tier.label}.',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (id == null) return;
            Navigator.pop(dialogContext);
            final res = await BuddyActions.respond(
              invitationId: id,
              accept: false,
            );
            final root = AppRouter.navigatorKey.currentContext;
            if (root != null && root.mounted) {
              ScaffoldMessenger.of(root).showSnackBar(
                SnackBar(
                  content: Text(
                    res['success'] == true
                        ? 'Invitation declined'
                        : (res['message']?.toString() ??
                              root.l10n.common_failed),
                  ),
                ),
              );
            }
          },
          child: const Text('Decline'),
        ),
        TextButton(
          onPressed: () async {
            if (id == null) return;
            Navigator.pop(dialogContext);
            final res = await BuddyActions.respond(
              invitationId: id,
              accept: true,
            );
            final root = AppRouter.navigatorKey.currentContext;
            if (root != null && root.mounted) {
              ScaffoldMessenger.of(root).showSnackBar(
                SnackBar(
                  content: Text(
                    res['success'] == true
                        ? 'You are now ${tier.label}s!'
                        : (res['message']?.toString() ??
                              root.l10n.common_failed),
                  ),
                  backgroundColor: res['success'] == true
                      ? Colors.green
                      : Colors.redAccent,
                ),
              );
            }
          },
          child: Text(
            dialogContext.l10n.cp_accept,
            style: TextStyle(
              color: _tierAccent(tier),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

void openBuddyInviteFromNotification(Map<String, dynamic> notif) {
  try {
    final raw = notif['metadata'];
    Map<String, dynamic>? meta;
    if (raw is Map) {
      meta = Map<String, dynamic>.from(raw);
    }
    final invitationId = meta?['invitation_id']?.toString();
    if (invitationId == null || invitationId.isEmpty) return;
    openBuddyInviteAcceptScreen(null, invitationId: invitationId);
  } catch (_) {}
}

Color _tierAccent(BuddyTier tier) {
  switch (tier) {
    case BuddyTier.friend:
      return const Color(0xFF4DA3FF);
    case BuddyTier.bestie:
      return const Color(0xFF3DCC6E);
    case BuddyTier.homie:
      return const Color(0xFFFF8A2B);
  }
}

Future<void> showBuddyInviteSheet(
  BuildContext context, {
  required WidgetRef ref,
  required BuddyTier tier,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BuddyInviteSheet(tier: tier),
  );
}

class _BuddyInviteSheet extends ConsumerWidget {
  const _BuddyInviteSheet({required this.tier});

  final BuddyTier tier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleAsync = ref.watch(buddyEligibleProvider(tier.dbValue));
    final height = MediaQuery.of(context).size.height * 0.72;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Invite',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              tier.inviteRuleText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: eligibleAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const _EmptyEligible();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final user = list[index];
                    final userId = user['user_id']?.toString() ?? '';
                    final name =
                        user['username']?.toString() ??
                        context.l10n.common_user;
                    final avatar = user['avatar_url']?.toString();
                    final intimacy = (user['intimacy'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: avatar != null
                            ? NetworkImage(avatar)
                            : null,
                        child: avatar == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${context.l10n.intimacy_title} ${NumberFormatter.format(intimacy)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final res = await BuddyActions.invite(
                            inviteeId: userId,
                            tier: tier,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['success'] == true
                                    ? 'Invitation sent to $name'
                                    : (res['message']?.toString() ??
                                          context.l10n.common_failed),
                              ),
                              backgroundColor: res['success'] == true
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          );
                          ref.invalidate(buddyEligibleProvider(tier.dbValue));
                        },
                        child: Text(
                          'Invite',
                          style: TextStyle(
                            color: _tierAccent(tier),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEligible extends StatelessWidget {
  const _EmptyEligible();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline, size: 72, color: Colors.black26),
        SizedBox(height: 16),
        Text(
          'No eligible friends yet',
          style: TextStyle(
            color: Colors.black45,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
