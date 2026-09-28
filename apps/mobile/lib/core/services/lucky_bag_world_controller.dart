import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/suppress_global_patti_provider.dart';

class WorldLuckyBagAnnouncement {
  WorldLuckyBagAnnouncement({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.totalCoins,
    required this.recipientCount,
    this.senderName,
  });

  final String id;
  final String roomId;
  final String senderId;
  final int totalCoins;
  final int recipientCount;
  final String? senderName;

  factory WorldLuckyBagAnnouncement.fromRecord(Map<String, dynamic> record) {
    return WorldLuckyBagAnnouncement(
      id: record['id'].toString(),
      roomId: record['room_id'].toString(),
      senderId: record['sender_id'].toString(),
      totalCoins: (record['total_coins'] as num?)?.toInt() ?? 0,
      recipientCount: (record['recipient_count'] as num?)?.toInt() ?? 0,
      senderName: record['sender_name']?.toString(),
    );
  }
}

class LuckyBagWorldBroadcastState {
  const LuckyBagWorldBroadcastState({this.currentBag});

  final WorldLuckyBagAnnouncement? currentBag;

  bool get isShowing => currentBag != null;
}

class LuckyBagWorldController extends Notifier<LuckyBagWorldBroadcastState> {
  final List<WorldLuckyBagAnnouncement> _queue = [];
  final Set<String> _seenIds = {};
  RealtimeChannel? _channel;
  bool _subscribed = false;

  @override
  LuckyBagWorldBroadcastState build() {
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

    return const LuckyBagWorldBroadcastState();
  }

  void _reset() {
    _unsubscribe();
    _queue.clear();
    _seenIds.clear();
    state = const LuckyBagWorldBroadcastState();
  }

  void _subscribe() {
    if (_subscribed) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _subscribed = true;
    _channel = Supabase.instance.client.channel('lucky_bag_world_broadcast');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'lucky_bags',
          callback: (payload) async {
            try {
              final record = Map<String, dynamic>.from(payload.newRecord);
              if (record['scope']?.toString() != 'world') return;
              if (record['status']?.toString() != 'active') return;

              String? senderName;
              try {
                final sender = await Supabase.instance.client
                    .from('users')
                    .select('username')
                    .eq('id', record['sender_id'])
                    .maybeSingle();
                senderName = sender?['username']?.toString();
              } catch (_) {}

              final bag = WorldLuckyBagAnnouncement.fromRecord({
                ...record,
                'sender_name': senderName,
              });
              if (bag.id.isEmpty) return;
              _enqueue(bag);
            } catch (e) {
              debugPrint('LuckyBagWorld parse error: $e');
            }
          },
        )
        .subscribe();
  }

  void _unsubscribe() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    _channel = null;
    _subscribed = false;
  }

  void _enqueue(WorldLuckyBagAnnouncement bag) {
    if (ref.read(suppressGlobalPattiProvider)) return;
    if (_seenIds.contains(bag.id)) return;
    _seenIds.add(bag.id);
    if (_seenIds.length > 100) {
      _seenIds.remove(_seenIds.first);
    }

    if (state.currentBag == null) {
      state = LuckyBagWorldBroadcastState(currentBag: bag);
    } else {
      _queue.add(bag);
    }
  }

  void dismissCurrent() {
    if (_queue.isEmpty) {
      state = const LuckyBagWorldBroadcastState();
    } else {
      state = LuckyBagWorldBroadcastState(currentBag: _queue.removeAt(0));
    }
  }

  void clearPlayback() {
    _queue.clear();
    if (state.currentBag != null) {
      state = const LuckyBagWorldBroadcastState();
    }
  }
}

final luckyBagWorldControllerProvider =
    NotifierProvider<LuckyBagWorldController, LuckyBagWorldBroadcastState>(
      LuckyBagWorldController.new,
    );
