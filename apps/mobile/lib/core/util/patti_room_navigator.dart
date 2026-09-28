import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PattiRoomNavigator {
  PattiRoomNavigator._();

  static Future<void> openRoom(
    BuildContext context,
    String? roomId, {
    WidgetRef? ref,
  }) async {
    final id = roomId?.trim();
    if (id == null || id.isEmpty) {
      _snack(context, 'Room not available');
      return;
    }

    if (ref != null) {
      final liveId = ref.read(currentLiveRoomIdProvider);
      if (liveId == id) {
        _snack(context, 'Already in this room');
        return;
      }
    }

    try {
      final room = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (!context.mounted) return;
      if (room == null) {
        _snack(context, 'Room not found');
        return;
      }

      final navCtx = AppRouter.navigatorKey.currentContext ?? context;
      await openRoomLive(navCtx, Map<String, dynamic>.from(room));
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Could not open room');
      }
    }
  }

  static void _snack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
