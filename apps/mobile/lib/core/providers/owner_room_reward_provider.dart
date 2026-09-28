import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/room_reward_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ownerRoomRewardProgressProvider =
    FutureProvider.family<RoomRewardProgress, String>((ref, roomId) async {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_owner_room_reward_progress',
          params: {'p_room_id': roomId},
        );
        if (res is Map) {
          final map = Map<String, dynamic>.from(res);
          if (map['success'] == false) {
            debugPrint('[ownerRoomReward] progress failed: ${map['message']}');
            return RoomRewardProgress.empty();
          }
          return RoomRewardProgress.fromMap(map);
        }
        return RoomRewardProgress.empty();
      } catch (e) {
        debugPrint('[ownerRoomReward] progress error: $e');
        return RoomRewardProgress.empty();
      }
    });

final ownerRoomRewardClaimsProvider =
    FutureProvider.family<List<RoomRewardClaimRecord>, String>((
      ref,
      roomId,
    ) async {
      try {
        final res = await Supabase.instance.client.rpc(
          'get_owner_room_reward_claims',
          params: {'p_room_id': roomId},
        );
        if (res is Map) {
          final map = Map<String, dynamic>.from(res);
          final claimsRaw = map['claims'];
          if (claimsRaw is! List) return [];
          return claimsRaw
              .whereType<Map>()
              .map(
                (e) =>
                    RoomRewardClaimRecord.fromMap(Map<String, dynamic>.from(e)),
              )
              .toList();
        }
        return [];
      } catch (e) {
        debugPrint('[ownerRoomReward] claims error: $e');
        return [];
      }
    });

final ownerHostedRoomIdProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  if (userId.isEmpty) return null;
  try {
    final res = await Supabase.instance.client
        .from('rooms')
        .select('id')
        .eq('host_id', userId)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    final id = res['id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  } catch (e) {
    debugPrint('[ownerRoomReward] hosted room lookup error: $e');
    return null;
  }
});

class OwnerRoomRewardService {
  static Future<Map<String, dynamic>> openBox({
    required String roomId,
    required int level,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'open_owner_room_reward_box',
        params: {'p_room_id': roomId, 'p_level': level},
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'success': false, 'message': 'Unexpected response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
