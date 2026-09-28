import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class LuckyBagTier {
  LuckyBagTier({
    required this.id,
    required this.label,
    required this.totalCoins,
    required this.recipientOptions,
  });

  final String id;
  final String label;
  final int totalCoins;
  final List<int> recipientOptions;

  factory LuckyBagTier.fromMap(Map<String, dynamic> map) {
    final options = map['recipient_options'];
    return LuckyBagTier(
      id: map['id'].toString(),
      label: map['label']?.toString() ?? '',
      totalCoins: (map['total_coins'] as num?)?.toInt() ?? 0,
      recipientOptions: options is List
          ? options.map((e) => (e as num).toInt()).toList()
          : [5, 10, 20, 30],
    );
  }
}

class LuckyBagActiveBag {
  LuckyBagActiveBag({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.scope,
    required this.totalCoins,
    required this.recipientCount,
    required this.claimedCount,
    required this.remainingCoins,
    required this.status,
    this.senderName,
    this.expiresAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String scope;
  final int totalCoins;
  final int recipientCount;
  final int claimedCount;
  final int remainingCoins;
  final String status;
  final String? senderName;
  final DateTime? expiresAt;

  bool get isActive => status == 'active';
  int get slotsLeft => recipientCount - claimedCount;

  factory LuckyBagActiveBag.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'];
    return LuckyBagActiveBag(
      id: map['id'].toString(),
      roomId: map['room_id'].toString(),
      senderId: map['sender_id'].toString(),
      scope: map['scope']?.toString() ?? 'room',
      totalCoins: (map['total_coins'] as num?)?.toInt() ?? 0,
      recipientCount: (map['recipient_count'] as num?)?.toInt() ?? 0,
      claimedCount: (map['claimed_count'] as num?)?.toInt() ?? 0,
      remainingCoins: (map['remaining_coins'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'active',
      senderName: sender is Map ? sender['username']?.toString() : null,
      expiresAt: DateTime.tryParse(
        map['expires_at']?.toString() ?? '',
      )?.toUtc(),
    );
  }
}

class LuckyBagIssuedHistoryItem {
  LuckyBagIssuedHistoryItem({
    required this.id,
    required this.totalCoins,
    required this.recipientCount,
    required this.claimedCount,
    required this.scope,
    required this.status,
    required this.createdAt,
    this.tierLabel,
  });

  final String id;
  final int totalCoins;
  final int recipientCount;
  final int claimedCount;
  final String scope;
  final String status;
  final DateTime? createdAt;
  final String? tierLabel;

  factory LuckyBagIssuedHistoryItem.fromMap(Map<String, dynamic> map) {
    final tier = map['tier'];
    return LuckyBagIssuedHistoryItem(
      id: map['id'].toString(),
      totalCoins: (map['total_coins'] as num?)?.toInt() ?? 0,
      recipientCount: (map['recipient_count'] as num?)?.toInt() ?? 0,
      claimedCount: (map['claimed_count'] as num?)?.toInt() ?? 0,
      scope: map['scope']?.toString() ?? 'room',
      status: map['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      tierLabel: tier is Map ? tier['label']?.toString() : null,
    );
  }
}

class LuckyBagReceivedHistoryItem {
  LuckyBagReceivedHistoryItem({
    required this.id,
    required this.coins,
    required this.claimedAt,
    required this.scope,
    this.senderName,
  });

  final String id;
  final int coins;
  final DateTime? claimedAt;
  final String scope;
  final String? senderName;

  factory LuckyBagReceivedHistoryItem.fromMap(Map<String, dynamic> map) {
    final bag = map['bag'];
    String? senderName;
    String scope = 'room';
    if (bag is Map) {
      scope = bag['scope']?.toString() ?? 'room';
      final sender = bag['sender'];
      if (sender is Map) {
        senderName = sender['username']?.toString();
      }
    }
    return LuckyBagReceivedHistoryItem(
      id: map['id'].toString(),
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      claimedAt: DateTime.tryParse(map['claimed_at']?.toString() ?? ''),
      scope: scope,
      senderName: senderName,
    );
  }
}

final luckyBagTiersProvider = FutureProvider<List<LuckyBagTier>>((ref) async {
  final response = await supabase
      .from('lucky_bag_tiers')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);
  return (response as List)
      .map((e) => LuckyBagTier.fromMap(Map<String, dynamic>.from(e)))
      .toList();
});

final luckyBagRulesProvider = FutureProvider<List<String>>((ref) async {
  final response = await supabase
      .from('lucky_bag_rules')
      .select('rules')
      .eq('id', 1)
      .maybeSingle();
  if (response == null) return [];
  final rules = response['rules'];
  if (rules is List) {
    return rules.map((e) => e.toString()).toList();
  }
  return [];
});

final roomLuckyBagsProvider =
    StreamProvider.family<List<LuckyBagActiveBag>, String>((ref, roomId) {
      final controller = StreamController<List<LuckyBagActiveBag>>.broadcast();

      Future<void> load() async {
        try {
          final response = await supabase
              .from('lucky_bags')
              .select('*, sender:sender_id(username)')
              .eq('room_id', roomId)
              .eq('status', 'active')
              .order('created_at', ascending: false);
          if (!controller.isClosed) {
            controller.add(
              (response as List)
                  .map(
                    (e) =>
                        LuckyBagActiveBag.fromMap(Map<String, dynamic>.from(e)),
                  )
                  .toList(),
            );
          }
        } catch (_) {
          if (!controller.isClosed) controller.add([]);
        }
      }

      final channel = supabase.channel('lucky_bags_room_$roomId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'lucky_bags',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (_) => load(),
          )
          .subscribe();

      load();
      ref.onDispose(() {
        supabase.removeChannel(channel);
        controller.close();
      });

      return controller.stream;
    });

final luckyBagIssuedHistoryProvider =
    FutureProvider.autoDispose<List<LuckyBagIssuedHistoryItem>>((ref) async {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('lucky_bags')
          .select('*, tier:tier_id(label)')
          .eq('sender_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List)
          .map(
            (e) =>
                LuckyBagIssuedHistoryItem.fromMap(Map<String, dynamic>.from(e)),
          )
          .toList();
    });

final luckyBagReceivedHistoryProvider =
    FutureProvider.autoDispose<List<LuckyBagReceivedHistoryItem>>((ref) async {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('lucky_bag_claims')
          .select('*, bag:bag_id(scope, sender:sender_id(username))')
          .eq('user_id', userId)
          .order('claimed_at', ascending: false)
          .limit(100);

      return (response as List)
          .map(
            (e) => LuckyBagReceivedHistoryItem.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    });

class LuckyBagService {
  static Future<Map<String, dynamic>> createBag({
    required String roomId,
    required String scope,
    required String tierId,
    required int recipientCount,
  }) async {
    final response = await supabase.rpc(
      'create_lucky_bag',
      params: {
        'p_room_id': roomId,
        'p_scope': scope,
        'p_tier_id': tierId,
        'p_recipient_count': recipientCount,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> claimBag(String bagId) async {
    final response = await supabase.rpc(
      'claim_lucky_bag',
      params: {'p_bag_id': bagId},
    );
    return Map<String, dynamic>.from(response as Map);
  }
}
