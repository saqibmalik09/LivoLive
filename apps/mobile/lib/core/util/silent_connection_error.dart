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
}) async* {
  T? last;
  try {
    last = await fetch();
    yield last as T;
  } catch (e) {
    debugPrint('realtimeWithFallback initial fetch: $e');
  }

  try {
    await for (final value in realtime()) {
      last = value;
      yield value;
    }
  } catch (e) {
    debugPrint('realtimeWithFallback stream suppressed: $e');
    if (last == null) {
      try {
        yield await fetch();
      } catch (e2) {
        debugPrint('realtimeWithFallback recovery fetch: $e2');
      }
    }
  }
}
