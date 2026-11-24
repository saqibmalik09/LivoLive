import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/room_bubble_native_bridge.dart';
import 'package:sk_live/core/services/room_exit_coordinator.dart';
import 'package:sk_live/core/services/room_floating_bubble_service.dart';
import 'package:sk_live/core/services/room_minimized_keepalive.dart';
import 'package:sk_live/core/services/room_voice_session_service.dart';
import 'package:sk_live/features/home/presentation/pages/room_live_screen.dart';

class RoomBubbleLifecycleHost extends ConsumerStatefulWidget {
  const RoomBubbleLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RoomBubbleLifecycleHost> createState() =>
      _RoomBubbleLifecycleHostState();
}

class _RoomBubbleLifecycleHostState
    extends ConsumerState<RoomBubbleLifecycleHost>
    with WidgetsBindingObserver {
  bool _showInProgress = false;
  bool _appInForeground = true;
  bool _exitInFlight = false;
  DateTime? _lastShowAttempt;
  DateTime? _lastOpenRoomAt;
  Timer? _showDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RoomFloatingBubbleService.setOverlayMessageHandler(_handleOverlayMessage);
    RoomBubbleNativeBridge.mainChannel.setMethodCallHandler(
      _onNativeBubbleAction,
    );
    unawaited(_consumePersistedPendingAction());
  }

  @override
  void dispose() {
    _showDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    RoomFloatingBubbleService.setOverlayMessageHandler(null);
    RoomBubbleNativeBridge.mainChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _consumePersistedPendingAction() async {
    final pending = await RoomBubbleNativeBridge.consumePendingAction();
    if (pending == null) return;
    _handleOverlayMessage(pending);
  }

  Future<void> _onNativeBubbleAction(MethodCall call) async {
    if (call.method != 'handleBubbleAction') return;
    final args = call.arguments;
    if (args is! Map) return;
    final payload = Map<String, dynamic>.from(args);
    _handleOverlayMessage(payload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!RoomFloatingBubbleService.isSupported) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _appInForeground = false;
      _showDebounce?.cancel();
      // System overlay bubble is off — do not request overlay permission or
      // draw over other apps. In-app minimize (MinimizedRoomOverlayHost) stays.
      if (!RoomFloatingBubbleService.showsSystemOverlayBubble) return;
      _showDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!_appInForeground) {
          unawaited(_maybeShowRoomBubble());
        }
      });
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _showDebounce?.cancel();
      _appInForeground = true;
      unawaited(_onAppResumed());
      return;
    }

    if (state == AppLifecycleState.detached) {
      _showDebounce?.cancel();
      unawaited(_onAppDetached());
      return;
    }
  }

  Future<void> _failClosedMuteOrLeave(String roomId) async {
    try {
      final muted = await OrbitVoiceSessionService.setMicEnabled(false);
      RoomFloatingBubbleService.micMuted = true;
      if (muted) return;
      debugPrint('[RoomBubble] mute failed — leave+disconnect fallback');
      await OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId);
    } catch (e) {
      debugPrint('[RoomBubble] fail-closed mute/leave: $e');
      try {
        await OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId);
      } catch (_) {}
    }
  }

  Future<void> _maybeShowRoomBubble() async {
    if (_showInProgress) return;
    if (_appInForeground) {
      debugPrint('[RoomBubble] skip show — still foreground');
      return;
    }

    var session = RoomFloatingBubbleService.cachedSession;
    if (session == null && mounted) {
      try {
        session = resolveActiveRoomSession(ref);
      } catch (e) {
        debugPrint('[RoomBubble] resolve session failed: $e');
      }
    }
    if (session == null) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_appInForeground) return;
      session = RoomFloatingBubbleService.cachedSession;
      if (session == null && mounted) {
        try {
          session = resolveActiveRoomSession(ref);
        } catch (_) {}
      }
    }
    if (session == null) {
      debugPrint('[RoomBubble] skip show — no active room session');
      return;
    }

    final roomId = session['id']?.toString();
    if (roomId == null || roomId.isEmpty) return;

    RoomFloatingBubbleService.cacheSession(session);

    if (!RoomFloatingBubbleService.showsSystemOverlayBubble) return;

    if (_appInForeground) return;

    _showInProgress = true;
    _lastShowAttempt = DateTime.now();
    try {
      final muted =
          RoomFloatingBubbleService.micMuted || session['muted'] == true;
      debugPrint('[RoomBubble] showing for room $roomId muted=$muted');
      final shown = await RoomFloatingBubbleService.showRoomBubble(
        roomId: roomId,
        title: session['title']?.toString() ?? 'Room',
        imageUrl: (session['avatar_url'] ?? session['image_url'])?.toString(),
        muted: muted,
      );

      if (_appInForeground) {
        await RoomFloatingBubbleService.hideRoomBubble(
          reason: RoomBubbleHideReason.appResumed,
        );
        if (mounted) {
          ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
        }
        return;
      }

      if (shown && mounted) {
        ref.read(roomSystemBubbleVisibleProvider.notifier).state = true;
        final liveRoomId = ref.read(currentLiveRoomIdProvider);
        if (liveRoomId == null) {
          if (!RoomMinimizedKeepAlive.isActive) {
            final profile = ref.read(userProfileProvider).valueOrNull;
            RoomMinimizedKeepAlive.saveVoiceState(
              seatIndex: RoomMinimizedKeepAlive.voiceSeatIndex,
              isMuted: RoomFloatingBubbleService.micMuted,
              orbitCanPublish:
                  RoomMinimizedKeepAlive.voiceOrbitCanPublish ?? true,
              localPublishing:
                  RoomMinimizedKeepAlive.voiceLocalPublishing ??
                  !RoomFloatingBubbleService.micMuted,
            );
            RoomMinimizedKeepAlive.start(
              roomId: roomId,
              user: RoomMinimizedKeepAlive.userPayload(profile: profile),
            );
          } else {
            RoomMinimizedKeepAlive.claimOrbitTransportHeal();
          }
        }
        debugPrint('[RoomBubble] visible=true keep-alive armed');
      } else {
        debugPrint('[RoomBubble] show failed — fail-closed mic mute');
        unawaited(_failClosedMuteOrLeave(roomId));
        if (mounted) {
          ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
        }
      }
    } finally {
      _showInProgress = false;
    }
  }

  Future<void> _hideRoomBubble({
    bool force = false,
    RoomBubbleHideReason reason = RoomBubbleHideReason.unspecified,
  }) async {
    if (!force) {
      final lastShow = _lastShowAttempt;
      if (lastShow != null &&
          DateTime.now().difference(lastShow) <
              const Duration(milliseconds: 800)) {
        return;
      }
    }

    await RoomFloatingBubbleService.hideRoomBubble(reason: reason);
    if (mounted) {
      ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
    }
  }

  Future<void> _onAppResumed() async {
    await _hideRoomBubble(force: true, reason: RoomBubbleHideReason.appResumed);
  }

  Future<void> _onAppDetached() async {
    unawaited(
      RoomFloatingBubbleService.hideRoomBubble(
        reason: RoomBubbleHideReason.roomExit,
      ),
    );
    final session = RoomFloatingBubbleService.cachedSession;
    final roomId = session?['id']?.toString();
    if (roomId == null) return;

    if (mounted) {
      clearActiveRoomState(ref);
    } else {
      RoomFloatingBubbleService.cacheSession(null);
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    unawaited(OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId));
    unawaited(RoomVoiceSessionService.stopAllRemotePlayback());
    unawaited(RoomVoiceSessionService.stopLocalPublish());
    unawaited(RoomLiveScreen.cleanupRoomStatic(roomId, userId));
  }

  Future<void> _hardExitRoom(String roomId) async {
    if (_exitInFlight) return;
    _exitInFlight = true;
    try {
      unawaited(RoomBubbleNativeBridge.acknowledgePendingAction());
      if (mounted) {
        await RoomExitCoordinator.leaveRoom(ref, roomId: roomId);
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        await OrbitVoiceSessionService.stopPublishAndLeave(roomId: roomId);
        await RoomVoiceSessionService.stopAllRemotePlayback();
        await RoomVoiceSessionService.stopLocalPublish();
        await RoomLiveScreen.cleanupRoomStatic(roomId, userId);
        RoomFloatingBubbleService.cacheSession(null);
      }
    } finally {
      _exitInFlight = false;
    }
  }

  void _handleOverlayMessage(Map<String, dynamic> payload) {
    final action = payload['action']?.toString();
    final roomId = payload['roomId']?.toString();
    if (action == null) return;

    switch (action) {
      case 'open_room':
        if (!mounted) return;
        final now = DateTime.now();
        if (_lastOpenRoomAt != null &&
            now.difference(_lastOpenRoomAt!) <
                const Duration(milliseconds: 900)) {
          break;
        }
        _lastOpenRoomAt = now;
        ref.read(roomSystemBubbleVisibleProvider.notifier).state = false;
        unawaited(
          RoomFloatingBubbleService.hideRoomBubble(
            reason: RoomBubbleHideReason.appResumed,
          ),
        );
        RoomExitCoordinator.returnToRoom(ref);
        break;
      case 'close_room':
      case 'bubble_removed':
        if (action == 'bubble_removed') {
          if (!RoomFloatingBubbleService.consumeUnexpectedRemoval()) {
            debugPrint('[RoomBubble] ignore unconfirmed/intentional removal');
            unawaited(RoomBubbleNativeBridge.acknowledgePendingAction());
            break;
          }
          if (_appInForeground) {
            debugPrint('[RoomBubble] ignore removal — app in foreground');
            unawaited(RoomBubbleNativeBridge.acknowledgePendingAction());
            break;
          }
          final lastShow = _lastShowAttempt;
          if (lastShow != null &&
              DateTime.now().difference(lastShow) <
                  const Duration(seconds: 3)) {
            debugPrint('[RoomBubble] removal right after show — mute only');
            final activeId =
                roomId ??
                RoomFloatingBubbleService.cachedSession?['id']?.toString();
            if (activeId != null && activeId.isNotEmpty) {
              unawaited(_failClosedMuteOrLeave(activeId));
            } else {
              unawaited(OrbitVoiceSessionService.setMicEnabled(false));
              RoomFloatingBubbleService.micMuted = true;
            }
            unawaited(RoomBubbleNativeBridge.acknowledgePendingAction());
            break;
          }
        }
        final activeSession = mounted ? resolveActiveRoomSession(ref) : null;
        final id =
            roomId ??
            activeSession?['id']?.toString() ??
            RoomFloatingBubbleService.cachedSession?['id']?.toString();
        if (id != null) {
          unawaited(_hardExitRoom(id));
        } else {
          unawaited(() async {
            await OrbitVoiceSessionService.disconnect();
            await RoomVoiceSessionService.stopAllRemotePlayback();
            await RoomVoiceSessionService.stopLocalPublish();
            await RoomFloatingBubbleService.hideRoomBubble(
              reason: RoomBubbleHideReason.roomExit,
            );
            await RoomBubbleNativeBridge.acknowledgePendingAction();
            if (mounted) clearActiveRoomState(ref);
          }());
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
