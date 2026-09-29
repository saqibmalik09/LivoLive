import 'package:flutter/material.dart';

bool shouldHideErrorFromUsers(Object? error) {
  if (error == null) return false;
  final type = error.runtimeType.toString();
  final msg = error.toString().toLowerCase();
  return type.contains('RealtimeSubscribe') ||
      msg.contains('realtimesubscribe') ||
      (msg.contains('realtime') && msg.contains('channel')) ||
      msg.contains('websocketchannel') ||
      msg.contains('websocket') ||
      msg.contains('failed host lookup') ||
      msg.contains('socketexception') ||
      msg.contains('connection timed out') ||
      msg.contains('network is unreachable') ||
      msg.contains('connection reset') ||
      msg.contains('clientexception') ||
      msg.contains('xmlhttprequest error');
}

Widget asyncErrorWidget(
  Object error, {
  TextStyle? style,
  String? fallbackMessage,
  AlignmentGeometry alignment = Alignment.center,
}) {
  if (shouldHideErrorFromUsers(error)) {
    debugPrint('Suppressed UI error: $error');
    return const SizedBox.shrink();
  }
  final text = fallbackMessage ?? 'Something went wrong. Pull to refresh.';
  return Align(
    alignment: alignment,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: style ?? const TextStyle(color: Colors.white54, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Stream<T> realtimeWithFallback<T>({
  required Future<T> Function() fetch,
  required Stream<T> Function() realtime,
  Duration retryDelay = const Duration(seconds: 3),
  Duration maxRetryDelay = const Duration(seconds: 30),
}) async* {
  // A dropped realtime subscription used to be swallowed whenever an earlier
  // fetch had succeeded, so the provider kept serving its last value until the
  // app restarted — the wallet showing a pre-transfer balance was this. Now the
  // stream ending for any reason re-fetches and re-subscribes with backoff.
  var delay = retryDelay;

  while (true) {
    try {
      yield await fetch();
      delay = retryDelay;
    } catch (e) {
      debugPrint('realtimeWithFallback fetch: $e');
    }

    try {
      await for (final value in realtime()) {
        yield value;
        delay = retryDelay;
      }
      debugPrint('realtimeWithFallback stream closed — resubscribing');
    } catch (e) {
      debugPrint('realtimeWithFallback stream error — resubscribing: $e');
    }

    await Future<void>.delayed(delay);
    final next = delay * 2;
    delay = next > maxRetryDelay ? maxRetryDelay : next;
  }
}
