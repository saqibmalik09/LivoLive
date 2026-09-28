import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PattiKind { globalWin, bigGift, entrance }

class PattiPlaybackGate extends Notifier<PattiKind?> {
  static const _holdTimeout = Duration(seconds: 20);

  String? _activeToken;
  final List<_PattiWaiter> _waiters = [];
  int _tokenSeq = 0;
  Timer? _holdTimer;

  @override
  PattiKind? build() => null;

  bool get isBusy => state != null;

  Future<String> acquire(PattiKind kind) async {
    final token = 'patti_${++_tokenSeq}';
    if (_activeToken == null) {
      _hold(token, kind);
      return token;
    }
    final completer = Completer<String>();
    _waiters.add(_PattiWaiter(kind: kind, token: token, completer: completer));
    return completer.future;
  }

  void release(String token) {
    if (_activeToken != token) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeAt(0);
      _hold(next.token, next.kind);
      if (!next.completer.isCompleted) {
        next.completer.complete(next.token);
      }
    } else {
      _activeToken = null;
      state = null;
    }
  }

  void _hold(String token, PattiKind kind) {
    _activeToken = token;
    state = kind;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdTimeout, () {
      if (_activeToken != token) return;
      debugPrint('PattiPlaybackGate force release: $kind');
      release(token);
    });
  }
}

class _PattiWaiter {
  _PattiWaiter({
    required this.kind,
    required this.token,
    required this.completer,
  });

  final PattiKind kind;
  final String token;
  final Completer<String> completer;
}

final pattiPlaybackGateProvider =
    NotifierProvider<PattiPlaybackGate, PattiKind?>(PattiPlaybackGate.new);
