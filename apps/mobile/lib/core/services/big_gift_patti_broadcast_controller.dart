import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/models/big_gift_patti_announcement.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/patti_playback_gate.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';

class BigGiftPattiBroadcastState {
  const BigGiftPattiBroadcastState({this.current});

  final BigGiftPattiAnnouncement? current;

  bool get isPlaying => current != null;
}

class BigGiftPattiBroadcastController
    extends Notifier<BigGiftPattiBroadcastState> {
  final List<BigGiftPattiAnnouncement> _queue = [];
  final Set<String> _seenIds = {};
  bool _subscribed = false;
  bool _holdingOrWaiting = false;
  String? _gateToken;

  @override
  BigGiftPattiBroadcastState build() {
    ref.onDispose(_unsubscribe);

    ref.listen(authStateProvider, (previous, next) {
      final hadSession = previous?.value?.session != null;
      final hasSession = next.value?.session != null;
      if (!hadSession && hasSession) {
        _subscribe();
      } else if (hadSession && !hasSession) {
        _reset();
      }
    });

    if (ref.watch(authStateProvider).value?.session != null) {
      Future.microtask(_subscribe);
    }

    return const BigGiftPattiBroadcastState();
  }

  void _reset() {
    _unsubscribe();
    _queue.clear();
    _seenIds.clear();
    _holdingOrWaiting = false;
    final token = _gateToken;
    _gateToken = null;
    if (token != null) {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    }
    state = const BigGiftPattiBroadcastState();
  }

  void _subscribe() {
    if (_subscribed || !AppConstants.useRealtimeGateway) return;
    if (Supabase.instance.client.auth.currentSession == null) return;

    _subscribed = true;
    final socket = RoomRealtimeSocket.instance;
    socket.onGlobalBigGift = (data) {
      try {
        final item = BigGiftPattiAnnouncement.fromJson(data);
        if (item.id.isEmpty && item.giftCoins <= 0) return;
        enqueue(item);
      } catch (e) {
        debugPrint('BigGiftPattiBroadcast gateway parse error: $e');
      }
    };
    unawaited(
      socket.ensureConnected().catchError((Object e) {
        debugPrint('BigGiftPattiBroadcast gateway connect: $e');
      }),
    );
    debugPrint('BigGiftPattiBroadcast listening via Redis gateway');
  }

  void _unsubscribe() {
    if (RoomRealtimeSocket.instance.onGlobalBigGift != null) {
      RoomRealtimeSocket.instance.onGlobalBigGift = null;
    }
    _subscribed = false;
  }

  void enqueue(BigGiftPattiAnnouncement item, {String? dedupeKey}) {
    if (ref.read(suppressGlobalPattiProvider)) return;
    final keys = <String>{
      if (dedupeKey != null && dedupeKey.isNotEmpty) dedupeKey,
      if (item.id.isNotEmpty) item.id,
    };
    if (keys.any(_seenIds.contains)) return;
    for (final key in keys) {
      _seenIds.add(key);
    }
    while (_seenIds.length > 120) {
      _seenIds.remove(_seenIds.first);
    }

    if (!_holdingOrWaiting && state.current == null) {
      unawaited(_present(item));
    } else {
      _queue.add(item);
    }
  }

  Future<void> _present(BigGiftPattiAnnouncement item) async {
    _holdingOrWaiting = true;
    final gate = ref.read(pattiPlaybackGateProvider.notifier);
    late final String token;
    try {
      token = await gate.acquire(PattiKind.bigGift);
    } catch (_) {
      _holdingOrWaiting = false;
      return;
    }
    _gateToken = token;
    state = BigGiftPattiBroadcastState(current: item);
  }

  void onFinished() {
    final token = _gateToken;
    _gateToken = null;
    state = const BigGiftPattiBroadcastState();
    _holdingOrWaiting = false;
    if (token != null) {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    }
    if (_queue.isNotEmpty) {
      unawaited(_present(_queue.removeAt(0)));
    }
  }

  void clearPlayback() {
    _queue.clear();
    _holdingOrWaiting = false;
    final token = _gateToken;
    _gateToken = null;
    if (token != null) {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    }
    if (state.current != null) {
      state = const BigGiftPattiBroadcastState();
    }
  }
}

final bigGiftPattiBroadcastControllerProvider =
    NotifierProvider<
      BigGiftPattiBroadcastController,
      BigGiftPattiBroadcastState
    >(BigGiftPattiBroadcastController.new);
