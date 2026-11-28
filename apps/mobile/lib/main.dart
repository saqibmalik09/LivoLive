/*
 * Livo / SK Live Party
 * App maintenance & design by NoxLab AI - https://noxlabai.com
 * Contact: https://noxlabai.com/quote | https://noxlabai.com/book
 * (c) 2026 NoxLab AI - maintenance and design updates
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/app_root.dart' deferred as app_root;
import 'package:sk_live/core/widgets/room_floating_bubble_overlay.dart';
import 'package:sk_live/zone_errors.dart';

// Release builds drop debugPrint. There are hundreds of call sites on hot
// paths (seat snapshots, presence, voice), and each one went through the
// throttled logcat writer on the UI isolate for output nobody reads.
// Profile and debug builds keep their logs.
void _silenceDebugPrintInRelease() {
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugPrintInRelease();
  overlayMainEntry();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _silenceDebugPrintInRelease();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // The native splash is removed when this first frame is drawn. The widget
  // below is a const colored box: no providers, no session read, no Supabase,
  // LiveKit, Hive, or Firebase. Those start from the post-frame callback.
  runZonedGuarded(() => runApp(const _FirstPaint()), reportZoneError);
}

class _FirstPaint extends StatefulWidget {
  const _FirstPaint();

  @override
  State<_FirstPaint> createState() => _FirstPaintState();
}

class _FirstPaintState extends State<_FirstPaint> {
  Widget? _app;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Frame 1 is already submitted. Wait one more so it can be presented
      // before any platform-channel work is queued.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_openAfterFirstFrames());
      });
    });
  }

  Future<void> _openAfterFirstFrames() async {
    var loaded = false;
    try {
      await app_root.loadLibrary();
      loaded = true;
      await app_root.mountAfterFirstPaint();
    } catch (e, st) {
      debugPrint('[BOOT] startup after first frame failed: $e\n$st');
    }
    if (!mounted || _app != null || !loaded) return;
    setState(() {
      _app = app_root.buildApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _app ?? const ColoredBox(color: Color(0xFF4E342E));
  }
}
