import 'package:flutter/material.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';

class RoomOverlayPermissionDialog {
  RoomOverlayPermissionDialog._();

  static Future<bool> showIfNeeded(BuildContext context) async {
    // System overlay bubble is retired — in-app minimize only.
    if (!RoomFloatingBubbleService.showsSystemOverlayBubble) return false;
    if (!RoomFloatingBubbleService.isSupported) return false;
    if (await RoomFloatingBubbleService.hasPermission()) return true;
    if (!context.mounted) return false;

    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.bubble_chart, color: Color(0xFFFFD700), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Floating room bubble',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Allow LIVO to show a small floating circle while you use '
          'other apps — like YouTube mini player.\n\n'
          'Tap Allow, then turn on "Display over other apps" for LIVO.\n\n'
          'On some phones (Xiaomi, Oppo, Vivo) also allow autostart / '
          'background running so the room stays live.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Not now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (enable != true) return false;

    final granted = await RoomFloatingBubbleService.requestPermission();
    if (granted) return true;

    return RoomFloatingBubbleService.hasPermission();
  }
}
