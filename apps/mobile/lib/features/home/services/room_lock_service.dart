import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';

bool roomIsLocked(Map<String, dynamic> room) {
  if (room['is_locked'] == true) return true;
  if (room['is_locked'] == null) {
    final pass = room['room_password']?.toString().trim() ?? '';
    return pass.isNotEmpty;
  }
  return false;
}

bool roomHasLockPassword(Map<String, dynamic> room) {
  final pass = room['room_password']?.toString().trim() ?? '';
  return pass.isNotEmpty;
}

final Map<String, DateTime> _roomUnlockUntil = {};

void _markRoomUnlocked(String roomId) {
  _roomUnlockUntil[roomId] = DateTime.now().add(const Duration(seconds: 90));
}

bool _wasRecentlyUnlocked(String roomId) {
  final until = _roomUnlockUntil[roomId];
  if (until == null) return false;
  if (until.isBefore(DateTime.now())) {
    _roomUnlockUntil.remove(roomId);
    return false;
  }
  return true;
}

Future<bool> _isRoomHostOrAdmin(String roomId, String? hostId) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  if (hostId != null && hostId == uid) return true;

  try {
    final row = await Supabase.instance.client
        .from('room_members')
        .select('role')
        .eq('room_id', roomId)
        .eq('user_id', uid)
        .maybeSingle();
    final role = row?['role']?.toString() ?? '';
    if (role == 'admin' || role == 'co_host' || role == 'host') return true;
  } catch (_) {}

  return currentUserIsSuperBd();
}

Future<String?> showRoomLockPasswordDialog(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Enter',
  bool requireNonEmpty = true,
  String initialValue = '',
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RoomLockPasswordDialog(
      title: title,
      confirmLabel: confirmLabel,
      requireNonEmpty: requireNonEmpty,
      initialValue: initialValue,
    ),
  );
}

Future<bool> ensureRoomUnlockedForEntry(
  BuildContext context,
  Map<String, dynamic> room,
) async {
  final roomId = room['id']?.toString();
  if (roomId == null) return false;

  Map<String, dynamic> latest = Map<String, dynamic>.from(room);
  try {
    final row = await Supabase.instance.client
        .from('rooms')
        // Deliberately does not select room_password: the device has no
        // legitimate need for it, and verification happens server-side.
        .select('id, host_id, is_locked')
        .eq('id', roomId)
        .maybeSingle();
    if (row != null) latest.addAll(Map<String, dynamic>.from(row));
  } catch (_) {}

  if (!roomIsLocked(latest)) return true;

  if (_wasRecentlyUnlocked(roomId)) return true;

  final hostId = latest['host_id']?.toString();
  if (await _isRoomHostOrAdmin(roomId, hostId)) {
    _markRoomUnlocked(roomId);
    return true;
  }

  if (!context.mounted) return false;
  final pass = await showRoomLockPasswordDialog(
    context,
    title: 'Room Locked',
    confirmLabel: 'Join',
  );
  if (pass == null || pass.isEmpty) return false;

  // Verification is server-side only. There used to be a fallback here that
  // compared the typed password against room_password fetched by the client —
  // which both required shipping the password to the device and let a tampered
  // client unlock any room. If the check cannot be performed, entry is denied.
  var message = 'Wrong password';
  try {
    final ok = await Supabase.instance.client.rpc(
      'verify_room_password',
      params: {'p_room_id': roomId, 'p_password': pass},
    );
    if (ok == true) {
      _markRoomUnlocked(roomId);
      return true;
    }
  } catch (e) {
    debugPrint('[room_lock] verify_room_password failed: $e');
    message = 'Could not verify the password. Please try again.';
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }
  return false;
}

Future<void> openRoomLive(
  BuildContext context,
  Map<String, dynamic> room, {
  bool skipLockCheck = false,
  bool replace = false,
}) async {
  final roomId = room['id']?.toString();
  if (roomId != null && roomId.isNotEmpty) {
    OrbitVoiceSessionService.prefetchSession(roomId);
  }
  if (!skipLockCheck) {
    final allowed = await ensureRoomUnlockedForEntry(context, room);
    if (!allowed || !context.mounted) return;
    if (roomId != null && roomId.isNotEmpty) {
      OrbitVoiceSessionService.claimPrefetch(roomId);
    }
  } else if (roomId != null) {
    _markRoomUnlocked(roomId);
  }
  if (!context.mounted) return;
  await AppTelemetry.traceAsync(
    'room_enter',
    () async {
      if (roomId != null) {
        unawaited(RoomFloatingBubbleService.hideRoomBubble());
        unawaited(AppTelemetry.setContext(roomId: roomId, screen: 'room_live'));
      }
      final route = MaterialPageRoute(
        builder: (_) => RoomLiveScreen(room: Map<String, dynamic>.from(room)),
      );
      if (replace) {
        await Navigator.pushReplacement(context, route);
      } else {
        await Navigator.push(context, route);
      }
    },
    keys: {'room_id': roomId ?? 'unknown'},
    slowMs: 8000,
  );
}

class _RoomLockPasswordDialog extends StatefulWidget {
  const _RoomLockPasswordDialog({
    required this.title,
    required this.confirmLabel,
    required this.requireNonEmpty,
    this.initialValue = '',
  });

  final String title;
  final String confirmLabel;
  final bool requireNonEmpty;
  final String initialValue;

  @override
  State<_RoomLockPasswordDialog> createState() =>
      _RoomLockPasswordDialogState();
}

class _RoomLockPasswordDialogState extends State<_RoomLockPasswordDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _error;

  void _submit() {
    final pass = _controller.text.trim();
    if (widget.requireNonEmpty && pass.length < 4) {
      // Used to return silently, so tapping Join with a short code looked like
      // the button was broken.
      setState(() => _error = 'Password must be 4-6 digits');
      return;
    }
    Navigator.pop(context, pass);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 6,
        style: const TextStyle(color: Colors.white, letterSpacing: 4),
        decoration: InputDecoration(
          hintText: '4-6 digit password',
          hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 0),
          counterStyle: const TextStyle(color: Colors.white38),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.amber),
          ),
          errorText: _error,
          errorStyle: const TextStyle(color: Colors.redAccent),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: Colors.amber),
          ),
        ),
      ],
    );
  }
}
