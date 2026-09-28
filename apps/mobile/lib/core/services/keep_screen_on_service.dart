import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class KeepScreenOnService {
  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[KeepScreenOn] enable failed: $e');
    }
  }

  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[KeepScreenOn] disable failed: $e');
    }
  }

  static void onAppLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        enable();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        disable();
        break;
    }
  }
}
