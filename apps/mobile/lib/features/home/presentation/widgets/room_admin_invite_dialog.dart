import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/room_invitation_provider.dart';
import 'package:sk_live/core/router/app_router.dart';

Future<void> openRoomAdminInviteAcceptScreen(
  BuildContext? context, {
  String? invitationId,
  Map<String, dynamic>? invitation,
}) async {
  final ctx = context ?? AppRouter.navigatorKey.currentContext;
  if (ctx == null) return;

  Map<String, dynamic>? invite = invitation;

  if (invite == null && invitationId != null) {
    invite = await RoomInvitationActions.fetchPendingInvitation(
      invitationId,
      role: 'admin',
    );
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
  final room = invite['room'] as Map<String, dynamic>?;
  final inviterName = inviter?['username'] ?? 'Someone';
  final roomTitle = room?['title'] ?? 'this room';
  final id = invite['id']?.toString();

  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Sub-Admin Invitation',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$inviterName invited you to be Sub-Admin in room "$roomTitle".',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'Accept to manage seats, mute users, and help run this room.',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            if (id == null) return;
            try {
              await RoomInvitationActions.respondToInvitation(id, false);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Invitation declined')),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text(_formatError(e))));
              }
            }
          },
          child: const Text(
            'Decline',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            if (id == null) return;
            try {
              await RoomInvitationActions.respondToInvitation(id, true);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'You are now Sub-Admin! Inviter has been notified.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text(_formatError(e))));
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          child: const Text(
            'Accept',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

Future<void> openRoomAdminInviteFromNotification(
  Map<String, dynamic> notif,
) async {
  final metadata = notif['metadata'];
  Map<String, dynamic> meta = {};
  if (metadata is Map) {
    meta = Map<String, dynamic>.from(metadata);
  } else if (metadata is String && metadata.isNotEmpty) {
    try {
      meta = Map<String, dynamic>.from(jsonDecode(metadata) as Map);
    } catch (_) {}
  }

  final invitationId = meta['invitation_id']?.toString();
  if (invitationId == null) return;

  await openRoomAdminInviteAcceptScreen(null, invitationId: invitationId);
}

String _formatError(Object e) => e.toString().replaceFirst('Exception: ', '');
