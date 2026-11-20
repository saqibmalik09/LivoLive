import 'package:flutter/foundation.dart';

/// Set once Firebase is up. Until then zone errors only hit the console,
/// so the first frame does not import Crashlytics.
void Function(Object error, StackTrace stack)? zoneErrorHandler;

void reportZoneError(Object error, StackTrace stack) {
  final handler = zoneErrorHandler;
  if (handler != null) {
    handler(error, stack);
    return;
  }
  debugPrint('Uncaught: $error\n$stack');
}
