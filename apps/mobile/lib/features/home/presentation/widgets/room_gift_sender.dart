import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/room_win_card_util.dart';
import 'package:sk_live/features/home/services/room_live_broadcast.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';
import 'package:uuid/uuid.dart';

bool isLuckyCategoryName(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  return n == 'lucky' || n == 'luck';
}

bool isLuckyProCategoryName(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  return n == 'lucky pro' || n == 'lucky_pro' || n == 'luckypro';
}

class RepeatGiftSession {
  final List<String> targetIds;
  final bool sendToAll;
  final String targetUsername;
  final String? targetAvatarUrl;
  final String giftId;
  final String giftName;
  final int priceCoins;
  final String giftIcon;
  final String svgaUrl;
  final bool isFullScreen;
  final int quantity;
  final bool isLuckyGift;
  final bool isLuckyProGift;

  const RepeatGiftSession({
    required this.targetIds,
    this.sendToAll = false,
    required this.targetUsername,
    this.targetAvatarUrl,
    required this.giftId,
    required this.giftName,
    required this.priceCoins,
    required this.giftIcon,
    required this.svgaUrl,
    required this.isFullScreen,
    required this.quantity,
    this.isLuckyGift = false,
    this.isLuckyProGift = false,
  });

  bool get usesGatewaySettle =>
      AppConstants.useGatewayLuckyEngine && (isLuckyGift || isLuckyProGift);

  Map<String, dynamic> toGiftMap() => {
    'id': giftId,
    'name': giftName,
    'price_coins': priceCoins,
    'icon_url': giftIcon,
    'svga_url': svgaUrl,
    'is_full_screen': isFullScreen,
  };
}

int giftHostDiamondsFromRpc(Map<String, dynamic> rpc) {
  return (rpc['host_received'] as num?)?.toInt() ??
      (rpc['host_share'] as num?)?.toInt() ??
      0;
}

class RoomGiftSendOutcome {
  final bool success;
  final bool luckyWin;
  final int newWealthLevel;
  final String animationBatchId;
  final bool isLuckyGift;
  final bool isLuckyProGift;
  final int? luckyGiftsUntilBonus;
  final Map<String, dynamic>? messageInsert;
  final Map<String, dynamic>? broadcastPayload;
  final String? targetId;
  final String? giftLogId;
  final bool usesGatewayLuckyEngine;
  final bool settledOnGateway;
  final Map<String, dynamic>? seatGiftTotals;
  final String? errorMessage;

  const RoomGiftSendOutcome({
    required this.success,
    this.luckyWin = false,
    this.newWealthLevel = 1,
    required this.animationBatchId,
    this.isLuckyGift = false,
    this.isLuckyProGift = false,
    this.luckyGiftsUntilBonus,
    this.messageInsert,
    this.broadcastPayload,
    this.targetId,
    this.giftLogId,
    this.usesGatewayLuckyEngine = false,
    this.settledOnGateway = false,
    this.seatGiftTotals,
    this.errorMessage,
  });
}

Map<String, dynamic> buildRoomGiftMessageInsert({
  required String roomId,
  required Map<String, dynamic> myUser,
  required String targetId,
  required Map<String, dynamic> gift,
  required int quantity,
  required String animationBatchId,
  required String receiverName,
  required Map<String, dynamic> rpc,
  String? eventId,
}) {
  final luckyBonusWon = rpc['lucky_bonus_won'] == true;
  final luckyBonusCoins = (rpc['lucky_bonus_coins'] as num?)?.toInt() ?? 0;
  final isLuckyGift = rpc['is_lucky_gift'] == true;
  final isLuckyProGift = rpc['is_lucky_pro_gift'] == true;
  final luckyProBonusWon = rpc['lucky_pro_bonus_won'] == true;
  final luckyProBonusCoins =
      (rpc['lucky_pro_bonus_coins'] as num?)?.toInt() ?? 0;
  final giftValue = (gift['price_coins'] as num).toInt() * quantity;
  final giftLogId = rpc['gift_log_id']?.toString();
  final luckyEngine =
      rpc['lucky_engine']?.toString() ??
      (AppConstants.useGatewayLuckyEngine ? 'gateway' : 'postgres');
  final totalCost = (rpc['total_cost'] as num?)?.toInt() ?? giftValue;

  var bonusMultiplier = 1;
  var multiplierTier = 'x1';
  if (luckyBonusWon || luckyProBonusWon) {
    final bonusCoins = luckyProBonusWon ? luckyProBonusCoins : luckyBonusCoins;
    bonusMultiplier = RoomWinCardUtil.computeBonusMultiplier(
      rewardCoins: bonusCoins,
      giftValue: giftValue,
    );
    multiplierTier = RoomWinCardUtil.resolveMultiplierTier(bonusMultiplier);
  }

  final resolvedEventId = eventId ?? RoomLiveBroadcast.newEventId();

  return {
    'room_id': roomId,
    'user_id': myUser['id'],
    'content': (luckyBonusWon || luckyProBonusWon)
        ? 'sent ${quantity}x ${gift['name']} to $receiverName - You won ${luckyProBonusWon ? luckyProBonusCoins : luckyBonusCoins} ${luckyProBonusWon ? 'lucky pro' : 'lucky'} bonus!'
        : 'sent ${quantity}x ${gift['name']} to $receiverName',
    'type': 'gift',
    'metadata': {
      'event_id': resolvedEventId,
      'room_id': roomId,
      'gift_id': gift['id'],
      'quantity': quantity,
      'target_id': targetId,
      'gift_name': gift['name'],
      'gift_icon': gift['icon_url'],
      'svga_url': gift['svga_url'],
      'is_full_screen': gift['is_full_screen'] ?? false,
      'host_received': giftHostDiamondsFromRpc(rpc),
      'host_share': giftHostDiamondsFromRpc(rpc),
      'charm_credit': (rpc['charm_credit'] as num?)?.toInt() ?? 0,
      'price_coins': gift['price_coins'],
      'total_cost': totalCost,
      if (giftLogId != null && giftLogId.isNotEmpty) 'gift_log_id': giftLogId,
      'lucky_engine': luckyEngine,
      'receiver_username': receiverName,
      'sender_username': myUser['username'],
      'sender_avatar': myUser['avatar_url'],
      'is_lucky_gift': isLuckyGift,
      'lucky_bonus_won': luckyBonusWon,
      'lucky_bonus_coins': luckyBonusCoins,
      'is_lucky_pro_gift': isLuckyProGift,
      'lucky_pro_bonus_won': luckyProBonusWon,
      'lucky_pro_bonus_coins': luckyProBonusCoins,
      'bonus_multiplier': bonusMultiplier,
      'multiplier_tier': multiplierTier,
      'animation_batch_id': animationBatchId,
    },
  };
}

Map<String, dynamic> buildRoomGiftMessageForUi(Map<String, dynamic> insertRow) {
  final metadata = Map<String, dynamic>.from(
    insertRow['metadata'] as Map? ?? {},
  );
  return {
    'id': metadata['event_id'],
    'user_id': insertRow['user_id'],
    'content': insertRow['content'],
    'type': insertRow['type'],
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'metadata': metadata,
    'user': {
      'username': metadata['sender_username'],
      'avatar_url': metadata['sender_avatar'],
    },
  };
}

Future<void> persistRoomGiftMessage(
  SupabaseClient supabase,
  Map<String, dynamic> row,
) async {
  await supabase.from('room_messages').insert(row);
}

Future<RoomGiftSendOutcome> sendRoomGift({
  required SupabaseClient supabase,
  required String roomId,
  required Map<String, dynamic> myUser,
  required String targetId,
  required Map<String, dynamic> gift,
  required int quantity,
  required String animationBatchId,
  required List<Map<String, dynamic>> allMembers,
  bool persistMessage = false,
}) async {
  return AppTelemetry.traceAsync(
    'gift_send',
    () async {
      final response = await supabase.rpc(
        'send_gift',
        params: {
          'p_sender_id': myUser['id'],
          'p_receiver_id': targetId,
          'p_gift_id': gift['id'],
          'p_room_id': roomId,
          'p_quantity': quantity,
          if (AppConstants.useGatewayLuckyEngine) 'p_lucky_engine': 'gateway',
        },
      );

      if (response == null || response['success'] != true) {
        return RoomGiftSendOutcome(
          success: false,
          animationBatchId: animationBatchId,
        );
      }

      final rpc = Map<String, dynamic>.from(response as Map);
      final receiverName =
          allMembers.firstWhere(
            (m) => m['id'] == targetId,
            orElse: () => {'username': 'User'},
          )['username'] ??
          'User';

      final luckyBonusWon = rpc['lucky_bonus_won'] == true;
      final luckyProBonusWon = rpc['lucky_pro_bonus_won'] == true;
      final isLuckyGift = rpc['is_lucky_gift'] == true;
      final isLuckyProGift = rpc['is_lucky_pro_gift'] == true;
      final hostDiamonds = giftHostDiamondsFromRpc(rpc);
      final seatCredit = (rpc['charm_credit'] as num?)?.toInt() ?? hostDiamonds;
      final usesGateway =
          AppConstants.useGatewayLuckyEngine &&
          (isLuckyGift || isLuckyProGift) &&
          (rpc['lucky_engine']?.toString() == 'gateway' ||
              AppConstants.useGatewayLuckyEngine);

      final messageInsert = buildRoomGiftMessageInsert(
        roomId: roomId,
        myUser: myUser,
        targetId: targetId,
        gift: gift,
        quantity: quantity,
        animationBatchId: animationBatchId,
        receiverName: receiverName,
        rpc: rpc,
      );

      if (persistMessage) {
        // Same as the gateway path: the gift has already settled, this row is
        // only chat history, so it must not hold up the send.
        unawaited(
          persistRoomGiftMessage(supabase, messageInsert).catchError((
            Object e,
          ) {
            debugPrint('[gift] chat row persist failed: $e');
          }),
        );
      }

      final metadata = messageInsert['metadata'] as Map<String, dynamic>;
      final eventId = metadata['event_id']?.toString() ?? '';
      final messageForUi = buildRoomGiftMessageForUi(messageInsert);

      final broadcastPayload = {
        'event_id': eventId,
        'animation_batch_id': animationBatchId,
        'sender_id': myUser['id'].toString(),
        'target_ids': [targetId],
        'gift_icon': gift['icon_url']?.toString() ?? '',
        'quantity': quantity,
        'is_full_screen': gift['is_full_screen'] ?? false,
        'svga_url': gift['svga_url']?.toString() ?? '',
        if (usesGateway) 'lucky_engine': 'gateway',
        'seat_gift_delta': {targetId: seatCredit},
        'message': messageForUi,
      };

      return RoomGiftSendOutcome(
        success: true,
        luckyWin: luckyBonusWon || luckyProBonusWon,
        newWealthLevel: (rpc['new_wealth_level'] as num?)?.toInt() ?? 1,
        animationBatchId: animationBatchId,
        isLuckyGift: isLuckyGift,
        isLuckyProGift: isLuckyProGift,
        luckyGiftsUntilBonus: (rpc['lucky_gifts_until_bonus'] as num?)?.toInt(),
        messageInsert: messageInsert,
        broadcastPayload: broadcastPayload,
        targetId: targetId,
        giftLogId: rpc['gift_log_id']?.toString(),
        usesGatewayLuckyEngine: usesGateway,
      );
    },
    keys: {
      'room_id': roomId,
      'gift_id': gift['id']?.toString() ?? '',
      'quantity': quantity.toString(),
    },
    slowMs: 5000,
  );
}

Future<List<RoomGiftSendOutcome>> sendRoomGiftsMulti({
  required SupabaseClient supabase,
  required String roomId,
  required Map<String, dynamic> myUser,
  required List<String> targetIds,
  required Map<String, dynamic> gift,
  required int quantity,
  required String animationBatchId,
  required List<Map<String, dynamic>> allMembers,
  bool persistMessage = false,
}) async {
  if (targetIds.isEmpty) return const [];
  // Serialize fallback RPCs — parallel Future.wait stampeded the gift DB pool
  // under multi-seat / retry storms while Postgres still locked the sender.
  final out = <RoomGiftSendOutcome>[];
  for (final targetId in targetIds) {
    out.add(
      await sendRoomGift(
        supabase: supabase,
        roomId: roomId,
        myUser: myUser,
        targetId: targetId,
        gift: gift,
        quantity: quantity,
        animationBatchId: animationBatchId,
        allMembers: allMembers,
        persistMessage: persistMessage,
      ),
    );
  }
  return out;
}

Future<List<RoomGiftSendOutcome>> sendRoomGiftsViaGateway({
  required SupabaseClient supabase,
  required String roomId,
  required Map<String, dynamic> myUser,
  required List<String> targetIds,
  required Map<String, dynamic> gift,
  required int quantity,
  required String animationBatchId,
  required List<Map<String, dynamic>> allMembers,
  bool persistMessage = false,
}) async {
  if (targetIds.isEmpty) return const [];

  final socket = RoomRealtimeSocket.instance;
  if (!AppConstants.useGatewayLuckyEngine ||
      !AppConstants.useRealtimeGateway ||
      !socket.isConnected) {
    return sendRoomGiftsMulti(
      supabase: supabase,
      roomId: roomId,
      myUser: myUser,
      targetIds: targetIds,
      gift: gift,
      quantity: quantity,
      animationBatchId: animationBatchId,
      allMembers: allMembers,
      persistMessage: persistMessage,
    );
  }

  final clientOpId = const Uuid().v4();
  final sw = Stopwatch()..start();
  try {
    final ack = await socket.giftSend({
      'roomId': roomId,
      'gift_id': gift['id'].toString(),
      'target_ids': targetIds,
      'quantity': quantity,
      'animation_batch_id': animationBatchId,
      'client_op_id': clientOpId,
      'sender_username': myUser['username'],
      'sender_avatar': myUser['avatar_url'],
    });
    debugPrint(
      '[GIFT_GW_SEND] ${sw.elapsedMilliseconds}ms '
      'targets=${targetIds.length} ok=${ack?['ok']}',
    );

    if (ack == null || ack['ok'] != true) {
      final err = ack?['error']?.toString() ?? 'gift:send failed';
      debugPrint('[GIFT_GW_SEND] fallback RPC: $err');
      return sendRoomGiftsMulti(
        supabase: supabase,
        roomId: roomId,
        myUser: myUser,
        targetIds: targetIds,
        gift: gift,
        quantity: quantity,
        animationBatchId: animationBatchId,
        allMembers: allMembers,
        persistMessage: persistMessage,
      );
    }

    final seatTotals = ack['seat_gift_totals'] is Map
        ? Map<String, dynamic>.from(ack['seat_gift_totals'] as Map)
        : null;
    final luckyWinLogs = <String>{};
    final luckyWinsRaw = ack['lucky_wins'];
    if (luckyWinsRaw is List) {
      for (final w in luckyWinsRaw) {
        if (w is! Map) continue;
        final id = w['gift_log_id']?.toString();
        if (id != null && id.isNotEmpty) luckyWinLogs.add(id);
      }
    }

    final rawOutcomes = ack['outcomes'];
    final byTarget = <String, Map<String, dynamic>>{};
    if (rawOutcomes is List) {
      for (final row in rawOutcomes) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final tid = map['target_id']?.toString();
        if (tid != null) byTarget[tid] = map;
      }
    }

    final outcomes = <RoomGiftSendOutcome>[];
    for (final targetId in targetIds) {
      final row = byTarget[targetId];
      if (row == null || row['success'] != true) {
        outcomes.add(
          RoomGiftSendOutcome(
            success: false,
            animationBatchId: animationBatchId,
            errorMessage: row?['error_message']?.toString() ?? 'Failed',
            targetId: targetId,
            settledOnGateway: true,
            seatGiftTotals: seatTotals,
          ),
        );
        continue;
      }

      final isLuckyGift = row['is_lucky_gift'] == true;
      final isLuckyProGift = row['is_lucky_pro_gift'] == true;
      final giftLogId = row['gift_log_id']?.toString();
      final luckyWin = giftLogId != null && luckyWinLogs.contains(giftLogId);
      final message = row['message'] is Map
          ? Map<String, dynamic>.from(row['message'] as Map)
          : null;

      Map<String, dynamic>? messageInsert;
      if (message != null) {
        messageInsert = {
          'room_id': roomId,
          'user_id': myUser['id'],
          'content': message['content'],
          'type': 'gift',
          'metadata': message['metadata'] is Map
              ? Map<String, dynamic>.from(message['metadata'] as Map)
              : <String, dynamic>{},
        };
        if (persistMessage) {
          // Fire and forget: the gift is already settled and broadcast by this
          // point, and this row is only chat history. Awaiting it once per
          // recipient made sending to several seats visibly slow, and a failed
          // insert used to abort the whole send.
          unawaited(
            persistRoomGiftMessage(supabase, messageInsert).catchError((
              Object e,
            ) {
              debugPrint('[gift] chat row persist failed: $e');
            }),
          );
        }
      }

      final seatCredit =
          (row['seat_credit'] as num?)?.toInt() ??
          (row['charm_credit'] as num?)?.toInt() ??
          (row['host_received'] as num?)?.toInt() ??
          0;
      outcomes.add(
        RoomGiftSendOutcome(
          success: true,
          luckyWin: luckyWin,
          newWealthLevel: (row['new_wealth_level'] as num?)?.toInt() ?? 1,
          animationBatchId: animationBatchId,
          isLuckyGift: isLuckyGift,
          isLuckyProGift: isLuckyProGift,
          luckyGiftsUntilBonus: (row['lucky_gifts_until_bonus'] as num?)
              ?.toInt(),
          messageInsert: messageInsert,
          broadcastPayload: {
            'event_id': '${animationBatchId}_settle',
            'animation_batch_id': animationBatchId,
            'sender_id': myUser['id'].toString(),
            'target_ids': [targetId],
            'gift_icon': gift['icon_url']?.toString() ?? '',
            'quantity': quantity,
            'is_full_screen': gift['is_full_screen'] ?? false,
            'svga_url': gift['svga_url']?.toString() ?? '',
            'lucky_engine': 'gateway',
            'settled_on_gateway': true,
            if (seatCredit > 0) 'seat_gift_delta': {targetId: seatCredit},
            if (message != null) 'message': message,
          },
          targetId: targetId,
          giftLogId: giftLogId,
          usesGatewayLuckyEngine: true,
          settledOnGateway: true,
          seatGiftTotals: seatTotals,
        ),
      );
    }
    return outcomes;
  } catch (e) {
    debugPrint('[GIFT_GW_SEND] error → RPC fallback: $e');
    return sendRoomGiftsMulti(
      supabase: supabase,
      roomId: roomId,
      myUser: myUser,
      targetIds: targetIds,
      gift: gift,
      quantity: quantity,
      animationBatchId: animationBatchId,
      allMembers: allMembers,
      persistMessage: persistMessage,
    );
  }
}
