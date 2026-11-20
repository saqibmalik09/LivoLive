import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/util/dev_log.dart';

class RoomInfoNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String?> {
  @override
  Future<Map<String, dynamic>?> build(String? arg) async {
    final supabase = Supabase.instance.client;
    if (arg != null) {
      try {
        final response = await supabase
            .from('rooms')
            .select('*, room_stats(*), host:host_id(country_code)')
            .eq('id', arg)
            .maybeSingle();
        return response;
      } catch (e) {
        return null;
      }
    } else {
      final userProfile = await ref.watch(userProfileProvider.future);
      if (userProfile == null) return null;

      try {
        final response = await supabase
            .from('rooms')
            .select('*, room_stats(*), host:host_id(country_code)')
            .eq('host_id', userProfile['id'])
            .order('online_users_count', ascending: false)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        return response;
      } catch (e) {
        return null;
      }
    }
  }

  Future<bool> updateRoom(String roomId, Map<String, dynamic> updates) async {
    try {
      final supabase = Supabase.instance.client;
      devLog('--- [DEBUG] Updating Room $roomId with: $updates');
      await supabase.from('rooms').update(updates).eq('id', roomId);
      devLog('--- [DEBUG] Room updated successfully in Supabase');

      if (state.hasValue && state.value != null) {
        final currentData = Map<String, dynamic>.from(state.value!);
        currentData.addAll(updates);
        state = AsyncValue.data(currentData);
      } else {
        ref.invalidateSelf();
      }
      return true;
    } catch (e, stack) {
      devLog('--- [DEBUG] Error updating room: $e');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> createRoom(Map<String, dynamic> data) async {
    try {
      final supabase = Supabase.instance.client;
      final hostId = data['host_id']?.toString();
      if (hostId == null || hostId.isEmpty) return false;

      final existing = await supabase
          .from('rooms')
          .select('id')
          .eq('host_id', hostId)
          .limit(1)
          .maybeSingle();
      if (existing != null) {
        devLog('--- [DEBUG] Host already has a room: ${existing['id']}');
        ref.invalidateSelf();
        return false;
      }

      final roomData = {
        'room_topic': 'chat',
        'is_private': false,
        'created_at': DateTime.now().toIso8601String(),
        ...data,
      };

      devLog('--- [DEBUG] Creating Room with data: $roomData');
      await supabase.from('rooms').insert(roomData);
      devLog('--- [DEBUG] Room created successfully');

      ref.invalidateSelf();
      return true;
    } catch (e, stack) {
      devLog('--- [DEBUG] Error creating room: $e');
      devLog('--- [DEBUG] Stack trace: $stack');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> deleteRoom(String roomId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('rooms').delete().eq('id', roomId);
      ref.invalidateSelf();
      return true;
    } catch (e, stack) {
      devLog('--- [DEBUG] Error deleting room: $e');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

final roomInfoProvider =
    AsyncNotifierProvider.family<
      RoomInfoNotifier,
      Map<String, dynamic>?,
      String?
    >(RoomInfoNotifier.new);
