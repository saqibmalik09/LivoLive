import 'package:flutter/material.dart';

/// Retired. System floating bubble consent must never show.
/// In-app minimize uses [MinimizedRoomOverlayHost] only.
class RoomOverlayPermissionDialog {
  RoomOverlayPermissionDialog._();

  static Future<bool> showIfNeeded(BuildContext context) async => false;
}
