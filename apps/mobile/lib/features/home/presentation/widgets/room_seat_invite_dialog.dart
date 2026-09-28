import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/room_invitation_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

Future<void> openRoomSeatInviteAcceptScreen(
  BuildContext? context, {
  String? invitationId,
  Map<String, dynamic>? invitation,
  bool navigateToRoomOnAccept = true,
  VoidCallback? onAcceptedInRoom,
}) async {
  final ctx = context ?? AppRouter.navigatorKey.currentContext;
  if (ctx == null) return;

  Map<String, dynamic>? invite = invitation;

  if (invite == null && invitationId != null) {
    invite = await RoomInvitationActions.fetchPendingInvitation(
      invitationId,
      role: 'seat',
    );
  }

  if (invite == null) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Seat invitation expired or already handled'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return;
  }

  if (!ctx.mounted) return;

  final inviter = invite['inviter'] as Map<String, dynamic>?;
  final room = invite['room'] as Map<String, dynamic>?;
  final inviterName = inviter?['username'] ?? 'Admin';
  final roomTitle = room?['title'] ?? 'this room';
  final id = invite['id']?.toString();
  final seatIndex = invite['seat_index'] as int?;
  final seatLabel = seatIndex != null ? 'Seat ${seatIndex + 1}' : 'a mic seat';

  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Seat Invitation',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$inviterName invited you to sit on $seatLabel in room "$roomTitle".',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.35),
              ),
            ),
            child: const Text(
              'Accept to join the mic seat. You can unmute your mic after sitting.',
              style: TextStyle(color: Colors.greenAccent, fontSize: 12),
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
                  const SnackBar(content: Text('Seat invitation declined')),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(_formatSeatInviteError(e))),
                );
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
              if (navigateToRoomOnAccept) {
                await _openRoomAfterSeatAccept(ctx, invite!);
              } else {
                onAcceptedInRoom?.call();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('You are on the seat!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(_formatSeatInviteError(e))),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
          child: const Text(
            'Accept',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

Future<void> _openRoomAfterSeatAccept(
  BuildContext ctx,
  Map<String, dynamic> invite,
) async {
  final roomId = invite['room_id']?.toString();
  if (roomId == null || !ctx.mounted) return;

  final roomRow = await Supabase.instance.client
      .from('rooms')
      .select()
      .eq('id', roomId)
      .maybeSingle();

  if (!ctx.mounted) return;

  if (roomRow == null || roomRow['is_active'] == false) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text('Room is no longer live'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  ScaffoldMessenger.of(ctx).showSnackBar(
    const SnackBar(
      content: Text('You are on the seat! Opening room…'),
      backgroundColor: Colors.green,
    ),
  );

  await openRoomLive(
    ctx,
    Map<String, dynamic>.from(roomRow),
    skipLockCheck: true,
  );
}

Future<void> openRoomSeatInviteFromNotification(
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

  await openRoomSeatInviteAcceptScreen(null, invitationId: invitationId);
}

String _formatSeatInviteError(Object e) =>
    e.toString().replaceFirst('Exception: ', '');
