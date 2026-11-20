import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/models/global_win_announcement.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';
import 'package:sk_live/core/services/patti_playback_gate.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/global_win_svga_util.dart';
import 'package:sk_live/core/util/svga_cache.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:sk_live/features/home/services/room_win_sync_service.dart';

class GlobalWinBroadcastState {
  final GlobalWinAnnouncement? currentWin;

  const GlobalWinBroadcastState({this.currentWin});

  bool get isPlaying => currentWin != null;
}

class GlobalWinBroadcastController extends Notifier<GlobalWinBroadcastState> {
  static const _playbackTimeout = Duration(seconds: 10);

  static const _maxQueueAge = Duration(seconds: 25);
  static const _maxQueueLength = 6;

  final List<GlobalWinAnnouncement> _queue = [];
  final Set<String> _seenIds = {};
  RealtimeChannel? _channel;
  bool _subscribed = false;
  bool _holdingOrWaiting = false;
  String? _gateToken;
  Timer? _playbackTimer;

  @override
  GlobalWinBroadcastState build() {
    ref.onDispose(() {
      _playbackTimer?.cancel();
      _unsubscribe();
    });

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

    return const GlobalWinBroadcastState();
  }

  void _reset() {
    _unsubscribe();
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _queue.clear();
    _seenIds.clear();
    _holdingOrWaiting = false;
    final token = _gateToken;
    _gateToken = null;
    if (token != null) {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    }
    state = const GlobalWinBroadcastState();
  }

  /// Prewarm is best-effort: a failure here must never stop the subscription.
  Future<void> _prewarmBannerAnimations() async {
    for (final asset in <String>[
      ...GlobalWinSvgaUtil.luckyTierAssets,
      GlobalWinSvgaUtil.giftAsset,
    ]) {
      try {
        await SvgaCache.loadAsset(asset);
      } catch (e) {
        debugPrint('[svga] banner prewarm failed for $asset: $e');
      }
    }
  }

  void _subscribe() {
    if (_subscribed || !AppConstants.enableGlobalWinSvgaBroadcast) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _subscribed = true;

    // Decode the banner animations once, now, rather than when the first win
    // arrives — the overlay gives up if the decode is not ready in time.
    unawaited(_prewarmBannerAnimations());

    if (AppConstants.useRealtimeGateway) {
      _subscribeGateway();
      _subscribeSupabase(serverBroadcastOnly: true);
    } else {
      _subscribeSupabase();
    }
  }

  void _subscribeGateway() {
    final socket = RoomRealtimeSocket.instance;
    socket.onGlobalWin = (data) {
      try {
        final win = GlobalWinAnnouncement.fromJson(data);
        if (win.id.isEmpty && win.rewardCoins <= 0) return;
        _enqueue(win);
      } catch (e) {
        debugPrint('GlobalWinBroadcast gateway parse error: $e');
      }
    };
    unawaited(
      socket.ensureConnected().catchError((Object e) {
        debugPrint('GlobalWinBroadcast gateway connect: $e');
      }),
    );
    debugPrint('GlobalWinBroadcast listening via Redis gateway');
  }

  void _subscribeSupabase({bool serverBroadcastOnly = false}) {
    _channel = Supabase.instance.client.channel('global_win_app_broadcast');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'global_win_announcements',
          callback: (payload) {
            try {
              final row = Map<String, dynamic>.from(payload.newRecord);
              if (serverBroadcastOnly && row['server_broadcast'] != true) {
                return;
              }
              final win = GlobalWinAnnouncement.fromJson(row);
              if (win.id.isEmpty) return;
              _enqueue(win);
            } catch (e) {
              debugPrint('GlobalWinBroadcast parse error: $e');
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint('GlobalWinBroadcast subscribe error: $error');
          } else {
            debugPrint('GlobalWinBroadcast channel status: $status');
          }
        });
  }

  void _unsubscribe() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _channel = null;
    if (RoomRealtimeSocket.instance.onGlobalWin != null) {
      RoomRealtimeSocket.instance.onGlobalWin = null;
    }
    _subscribed = false;
  }

  void _enqueue(GlobalWinAnnouncement win, {String? dedupeKey}) {
    if (ref.read(suppressGlobalPattiProvider)) return;
    if (!GlobalWinSvgaUtil.showsTopBanner(win)) return;
    final keys = <String>{
      if (dedupeKey != null && dedupeKey.isNotEmpty) dedupeKey,
      if (win.id.isNotEmpty) win.id,
      RoomWinSyncService.fuzzyDedupeKey(win),
    };
    if (keys.any(_seenIds.contains)) return;
    for (final key in keys) {
      _seenIds.add(key);
    }
    while (_seenIds.length > 200) {
      _seenIds.remove(_seenIds.first);
    }

    if (!_holdingOrWaiting && state.currentWin == null) {
      unawaited(_present(win));
      return;
    }

    if (_isSelf(win)) {
      _queue.insert(0, win);
    } else {
      _queue.add(win);
    }
    _trimQueue();
  }

  bool _isSelf(GlobalWinAnnouncement win) {
    final self = Supabase.instance.client.auth.currentUser?.id;
    return self != null && win.userId == self;
  }

  bool _isStale(GlobalWinAnnouncement win) {
    if (_isSelf(win)) return false;
    final created = win.createdAt;
    if (created == null) return false;
    return DateTime.now().toUtc().difference(created) > _maxQueueAge;
  }

  void _trimQueue() {
    _queue.removeWhere(_isStale);
    while (_queue.length > _maxQueueLength) {
      final index = _queue.lastIndexWhere((w) => !_isSelf(w));
      _queue.removeAt(index >= 0 ? index : _queue.length - 1);
    }
  }

  GlobalWinAnnouncement? _takeNext() {
    while (_queue.isNotEmpty) {
      final win = _queue.removeAt(0);
      if (!_isStale(win)) return win;
    }
    return null;
  }

  Future<void> _present(GlobalWinAnnouncement win) async {
    _holdingOrWaiting = true;
    final gate = ref.read(pattiPlaybackGateProvider.notifier);
    late final String token;
    try {
      token = await gate.acquire(PattiKind.globalWin);
    } catch (_) {
      _holdingOrWaiting = false;
      return;
    }
    _gateToken = token;
    state = GlobalWinBroadcastState(currentWin: win);
    _playbackTimer?.cancel();
    _playbackTimer = Timer(_playbackTimeout, () {
      if (state.currentWin?.id != win.id) return;
      debugPrint('GlobalWinBroadcast playback timeout: ${win.id}');
      onFinished();
    });
  }

  void enqueueWin(GlobalWinAnnouncement win, {String? dedupeKey}) {
    _enqueue(win, dedupeKey: dedupeKey);
  }

  @Deprecated('Use enqueueWin')
  void enqueue(GlobalWinAnnouncement win) => enqueueWin(win);

  void onFinished() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    final token = _gateToken;
    _gateToken = null;
    state = const GlobalWinBroadcastState();
    _holdingOrWaiting = false;
    if (token != null) {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    }
    final next = _takeNext();
    if (next != null) {
      unawaited(_present(next));
    }
  }

  void clearPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _queue.clear();
    _holdingOrWaiting = false;
    final token = _gateToken;
    _gateToken = null;
    if (token != null) {
      ref.read(pattiPlaybackGateProvider.notifier).release(token);
    }
    if (state.currentWin != null) {
      state = const GlobalWinBroadcastState();
    }
  }
}

final globalWinBroadcastControllerProvider =
    NotifierProvider<GlobalWinBroadcastController, GlobalWinBroadcastState>(
      GlobalWinBroadcastController.new,
    );
