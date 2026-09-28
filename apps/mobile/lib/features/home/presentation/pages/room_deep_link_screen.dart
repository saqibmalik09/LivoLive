import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

class RoomDeepLinkScreen extends StatefulWidget {
  final String roomId;

  const RoomDeepLinkScreen({super.key, required this.roomId});

  @override
  State<RoomDeepLinkScreen> createState() => _RoomDeepLinkScreenState();
}

class _RoomDeepLinkScreenState extends State<RoomDeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRoom());
  }

  Future<void> _openRoom() async {
    try {
      final room = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('id', widget.roomId)
          .maybeSingle();

      if (!mounted) return;

      if (room == null) {
        _showError('Room not found or has ended.');
        return;
      }

      final roomMap = Map<String, dynamic>.from(room);
      if (roomMap['is_active'] == false) {
        _showError('This room is no longer live.');
        return;
      }

      final allowed = await ensureRoomUnlockedForEntry(context, roomMap);
      if (!allowed || !mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomLiveScreen(room: roomMap)),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Could not open room. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text('Opening room...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
