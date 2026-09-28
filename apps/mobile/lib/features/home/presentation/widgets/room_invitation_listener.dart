import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/room_invitation_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/room_admin_invite_dialog.dart';
import 'package:sk_live/features/home/presentation/widgets/room_seat_invite_dialog.dart';

class RoomInvitationListener extends ConsumerStatefulWidget {
  final Widget child;
  const RoomInvitationListener({super.key, required this.child});

  @override
  ConsumerState<RoomInvitationListener> createState() =>
      _RoomInvitationListenerState();
}

class _RoomInvitationListenerState
    extends ConsumerState<RoomInvitationListener> {
  final Set<String> _shownInvitationIds = {};

  Future<void> _showInvitation(Map<String, dynamic> invitation) async {
    final id = invitation['id']?.toString();
    if (id == null || _shownInvitationIds.contains(id)) return;

    _shownInvitationIds.add(id);
    final role = invitation['role']?.toString() ?? 'admin';

    try {
      if (role == 'seat') {
        await openRoomSeatInviteAcceptScreen(context, invitation: invitation);
      } else {
        await openRoomAdminInviteAcceptScreen(context, invitation: invitation);
      }
    } finally {
      _shownInvitationIds.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(roomInvitationProvider, (
      previous,
      next,
    ) {
      if (!next.hasValue || next.value!.isEmpty) return;

      final liveRoomId = ref.read(currentLiveRoomIdProvider);

      for (final invitation in next.value!) {
        final id = invitation['id']?.toString();
        if (id == null || _shownInvitationIds.contains(id)) continue;

        final role = invitation['role']?.toString() ?? 'admin';
        final invRoomId = invitation['room_id']?.toString();
        if (role == 'seat' && liveRoomId != null && invRoomId == liveRoomId) {
          continue;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showInvitation(invitation);
        });
        break;
      }
    });

    return widget.child;
  }
}
