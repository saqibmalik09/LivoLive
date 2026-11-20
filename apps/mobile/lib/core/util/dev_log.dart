import 'package:flutter/foundation.dart';

/// A log line that costs nothing in a release build.
///
/// `print` is **not** stripped from Flutter release builds — every call still
/// crosses to the platform logger. The room screen alone made 62 of these, on
/// paths that run per seat update, per chat message and per gift, so users were
/// paying for developer tracing in the hottest part of the app.
///
/// [debugPrint] additionally throttles output, so bursts no longer drop frames
/// while debugging.
void devLog(Object? message) {
  if (kDebugMode) debugPrint('$message');
}
