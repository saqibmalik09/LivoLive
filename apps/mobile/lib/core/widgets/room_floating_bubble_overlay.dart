import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sk_live/l10n/app_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk_live/core/l10n/app_locale.dart';
import 'package:sk_live/core/services/room_bubble_native_bridge.dart';

void overlayMainEntry() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  Locale _locale = const Locale(AppLocale.defaultCode);

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppLocale.prefsKey);
      if (!mounted) return;
      setState(() => _locale = AppLocale.resolve(code));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: RoomFloatingBubbleOverlay(),
      ),
    );
  }
}

class RoomFloatingBubbleOverlay extends StatefulWidget {
  const RoomFloatingBubbleOverlay({super.key});

  @override
  State<RoomFloatingBubbleOverlay> createState() =>
      _RoomFloatingBubbleOverlayState();
}

class _RoomFloatingBubbleOverlayState extends State<RoomFloatingBubbleOverlay>
    with SingleTickerProviderStateMixin {
  String _roomId = '';
  String? _imageUrl;
  bool _muted = true;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    FlutterOverlayWindow.overlayListener.listen(_applyPayload);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _applyPayload(dynamic data) {
    Map<String, dynamic>? map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (map == null) return;

    final action = map['action']?.toString();
    if (action != null && action.isNotEmpty) return;

    setState(() {
      _roomId = map!['roomId']?.toString() ?? _roomId;
      _imageUrl = map['imageUrl']?.toString();
      _muted = map['muted'] == true;
    });
  }

  Future<void> _openRoom() async {
    if (_roomId.isEmpty) return;
    await RoomBubbleNativeBridge.bringAppToForeground(
      action: 'open_room',
      roomId: _roomId,
    );
  }

  Future<void> _closeRoom() async {
    if (_roomId.isEmpty) return;
    try {
      await FlutterOverlayWindow.shareData({
        'action': 'close_room',
        'roomId': _roomId,
      });
    } catch (_) {}
    try {
      await RoomBubbleNativeBridge.cacheRoomId(_roomId);
    } catch (_) {}
    await RoomBubbleNativeBridge.bringAppToForeground(
      action: 'close_room',
      roomId: _roomId,
    );
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 12,
                child: GestureDetector(
                  onTap: _openRoom,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_pulse.value);
                      return Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFE08A),
                              Color(0xFFFF4D8D),
                              Color(0xFF7B61FF),
                              Color(0xFFFFD54F),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF4D8D,
                              ).withValues(alpha: 0.28 + t * 0.22),
                              blurRadius: 16 + t * 8,
                              spreadRadius: 0.5,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFFD54F,
                              ).withValues(alpha: 0.18 + t * 0.14),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2.2),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2A1458),
                            Color(0xFF12081F),
                            Color(0xFF1A0A2E),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 8,
                            left: 10,
                            child: Container(
                              width: 28,
                              height: 18,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.18),
                                    Colors.white.withValues(alpha: 0.02),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(child: _buildFramedAvatar()),
                          Positioned(
                            right: 7,
                            bottom: 7,
                            child: _buildMicChip(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _closeRoom,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFE53935,
                          ).withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFramedAvatar() {
    const avatarSize = 60.0;
    return SizedBox(
      width: 78,
      height: 78,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Container(
              width: avatarSize + 10 + t * 2,
              height: avatarSize + 10 + t * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFFFFF3C4),
                    Color(0xFFFFD54F),
                    Color(0xFFFF4D8D),
                    Color(0xFF7B61FF),
                    Color(0xFFFF8A00),
                    Color(0xFFFFF3C4),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFFD54F,
                    ).withValues(alpha: 0.22 + t * 0.2),
                    blurRadius: 8 + t * 6,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2.6),
              child: child,
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF12081F),
            ),
            padding: const EdgeInsets.all(1.6),
            child: ClipOval(
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: _imageUrl != null && _imageUrl!.isNotEmpty
                    ? Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackAvatar(),
                      )
                    : _fallbackAvatar(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicChip() {
    final live = !_muted;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: live
              ? const [Color(0xFF7CFFB2), Color(0xFF00C853)]
              : const [Color(0xFFFF8A80), Color(0xFFE53935)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (live ? const Color(0xFF00C853) : const Color(0xFFE53935))
                .withValues(alpha: 0.45),
            blurRadius: 6,
          ),
        ],
      ),
      child: Icon(
        live ? Icons.mic_rounded : Icons.mic_off_rounded,
        color: Colors.white,
        size: 12,
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFF2A1458),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Colors.white70, size: 28),
    );
  }
}
