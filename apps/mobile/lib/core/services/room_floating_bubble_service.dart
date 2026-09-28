import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:sk_live/core/services/room_bubble_native_bridge.dart';

enum RoomBubbleHideReason { appResumed, roomExit, serviceRemoved, unspecified }

class RoomFloatingBubbleService {
  RoomFloatingBubbleService._();

  static const double bubbleLogicalSize = 150;

  static int get _bubblePx {
    final views = PlatformDispatcher.instance.views;
    final dpr = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
    return (bubbleLogicalSize * (dpr <= 0 ? 1.0 : dpr)).round();
  }

  static const Duration _platformTimeout = Duration(seconds: 5);

  static bool micMuted = true;

  static bool overlayConfirmedActive = false;

  static DateTime? _intentionalHideAt;
  static const Duration _intentionalHideWindow = Duration(seconds: 10);

  static bool get intentionalHidePending {
    final at = _intentionalHideAt;
    return at != null && DateTime.now().difference(at) < _intentionalHideWindow;
  }

  @visibleForTesting
  static set intentionalHidePending(bool value) {
    _intentionalHideAt = value ? DateTime.now() : null;
  }

  static bool _listenerAttached = false;
  static void Function(Map<String, dynamic> payload)? _onOverlayMessage;
  static Map<String, dynamic>? _cachedSession;
  static Completer<bool>? _showLock;
  static int _showGeneration = 0;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Map<String, dynamic>? get cachedSession => _cachedSession;

  static void cacheSession(Map<String, dynamic>? session) {
    _cachedSession = session == null
        ? null
        : Map<String, dynamic>.from(session);
  }

  static void setOverlayMessageHandler(
    void Function(Map<String, dynamic> payload)? handler,
  ) {
    _onOverlayMessage = handler;
    _attachListenerOnce();
  }

  static void _attachListenerOnce() {
    if (_listenerAttached || !isSupported) return;
    _listenerAttached = true;
    FlutterOverlayWindow.overlayListener.listen((data) {
      final payload = _parsePayload(data);
      if (payload == null) return;
      final action = payload['action']?.toString();
      if (action == null || action.isEmpty) return;
      _onOverlayMessage?.call(payload);
    });
  }

  static Map<String, dynamic>? _parsePayload(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<T?> _platform<T>(
    Future<T> future, {
    required String label,
  }) async {
    try {
      return await future.timeout(_platformTimeout);
    } on TimeoutException {
      debugPrint('[RoomBubble] $label timed out');
      return null;
    } catch (e) {
      debugPrint('[RoomBubble] $label failed: $e');
      return null;
    }
  }

  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return await _platform(
          FlutterOverlayWindow.isPermissionGranted(),
          label: 'isPermissionGranted',
        ) ??
        false;
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final granted = await FlutterOverlayWindow.requestPermission().timeout(
        _platformTimeout,
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('[RoomBubble] requestPermission failed: $e');
      return false;
    }
  }

  static Future<bool> isShowing() async {
    if (!isSupported) return false;
    return await _platform(
          FlutterOverlayWindow.isActive(),
          label: 'isActive',
        ) ??
        false;
  }

  static Future<bool> isConfirmedActive() async {
    if (!isSupported) return false;
    if (await isShowing()) {
      overlayConfirmedActive = true;
      return true;
    }
    return overlayConfirmedActive;
  }

  static Future<bool> showRoomBubble({
    required String roomId,
    required String title,
    String? imageUrl,
    bool muted = false,
  }) async {
    if (!isSupported) return false;

    final pending = _showLock;
    if (pending != null) {
      try {
        await pending.future.timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    final lock = Completer<bool>();
    _showLock = lock;
    final gen = ++_showGeneration;
    _intentionalHideAt = null;

    _attachListenerOnce();
    micMuted = muted;
    unawaited(RoomBubbleNativeBridge.cacheRoomId(roomId));

    try {
      if (!await hasPermission()) {
        debugPrint('[RoomBubble] overlay permission not granted');
        overlayConfirmedActive = false;
        lock.complete(false);
        return false;
      }

      if (await isShowing()) {
        await shareRoomData(
          roomId: roomId,
          title: title,
          imageUrl: imageUrl,
          muted: muted,
        );
        overlayConfirmedActive = true;
        debugPrint('[RoomBubble] updated existing overlay');
        lock.complete(true);
        return true;
      }

      await shareRoomData(
        roomId: roomId,
        title: title,
        imageUrl: imageUrl,
        muted: muted,
      );

      final sizePx = _bubblePx;
      await _platform(
        FlutterOverlayWindow.showOverlay(
          height: sizePx,
          width: sizePx,
          alignment: OverlayAlignment.centerRight,
          enableDrag: true,
          overlayTitle: 'LIVO Room',
          overlayContent: title,
          visibility: NotificationVisibility.visibilityPublic,
          flag: OverlayFlag.defaultFlag,
          positionGravity: PositionGravity.auto,
          startPosition: const OverlayPosition(0, 280),
        ),
        label: 'showOverlay',
      );

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (gen != _showGeneration) {
        debugPrint('[RoomBubble] show superseded — abort');
        lock.complete(false);
        return false;
      }

      await shareRoomData(
        roomId: roomId,
        title: title,
        imageUrl: imageUrl,
        muted: muted,
      );

      final active = await isShowing();
      overlayConfirmedActive = active;
      debugPrint(
        '[RoomBubble] overlay ${active ? 'shown' : 'NOT active after show'} '
        'for room $roomId',
      );
      lock.complete(active);
      return active;
    } catch (e, st) {
      debugPrint('[RoomBubble] showOverlay failed: $e');
      debugPrint('$st');
      overlayConfirmedActive = false;
      if (!lock.isCompleted) lock.complete(false);
      return false;
    } finally {
      if (identical(_showLock, lock)) {
        _showLock = null;
      }
      if (!lock.isCompleted) lock.complete(false);
    }
  }

  static Future<void> shareRoomData({
    required String roomId,
    required String title,
    String? imageUrl,
    bool muted = false,
  }) async {
    if (!isSupported) return;
    micMuted = muted;
    await _platform(
      FlutterOverlayWindow.shareData({
        'roomId': roomId,
        'title': title,
        'imageUrl': imageUrl,
        'muted': muted,
      }),
      label: 'shareData',
    );
  }

  static Future<void> syncMicMuted(bool muted) async {
    micMuted = muted;
    final session = _cachedSession;
    final roomId = session?['id']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    if (!overlayConfirmedActive && !await isShowing()) return;
    await shareRoomData(
      roomId: roomId,
      title: session?['title']?.toString() ?? 'Room',
      imageUrl: (session?['avatar_url'] ?? session?['image_url'])?.toString(),
      muted: muted,
    );
  }

  static Future<void> hideRoomBubble({
    RoomBubbleHideReason reason = RoomBubbleHideReason.unspecified,
  }) async {
    if (!isSupported) return;
    _showGeneration++;
    final intentional =
        reason == RoomBubbleHideReason.appResumed ||
        reason == RoomBubbleHideReason.roomExit ||
        reason == RoomBubbleHideReason.unspecified;
    _intentionalHideAt = intentional ? DateTime.now() : null;
    try {
      if (await isShowing()) {
        await _platform(
          FlutterOverlayWindow.closeOverlay(),
          label: 'closeOverlay',
        );
        debugPrint('[RoomBubble] overlay closed reason=$reason');
      }
    } catch (e) {
      debugPrint('[RoomBubble] hide failed: $e');
    } finally {
      overlayConfirmedActive = false;
    }
  }

  static bool consumeUnexpectedRemoval() {
    final wasActive = overlayConfirmedActive;
    overlayConfirmedActive = false;
    if (intentionalHidePending) return false;
    return wasActive;
  }
}
