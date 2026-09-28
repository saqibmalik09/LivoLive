import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/services/dm_realtime_hub.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/features/home/services/room_realtime_socket.dart';

final supabase = Supabase.instance.client;

bool get _dmGw => AppConstants.useDmGateway && AppConstants.useRealtimeGateway;

bool _isMessagesTabActive(Ref ref) {
  final idx = ref.read(bottomNavIndexProvider);
  final items = ref.read(bottomNavConfigProvider).valueOrNull ?? [];
  if (idx < 0 || idx >= items.length) return false;
  return items[idx].navKey == 'message';
}

final conversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (_dmGw) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  debugPrint('[CHAT_STREAM]: Starting conversations stream for user: $userId');

  final stream1 = supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .eq('participant_1_id', userId);

  final stream2 = supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .eq('participant_2_id', userId);

  return Rx.combineLatest2<
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>,
        List<Map<String, dynamic>>
      >(stream1, stream2, (list1, list2) {
        final combined = [...list1, ...list2];
        combined.sort(
          (a, b) => (b['last_message_at'] as String).compareTo(
            a['last_message_at'] as String,
          ),
        );
        return combined;
      })
      .handleError((error) {
        debugPrint('[CHAT_STREAM_ERROR]: Conversations stream failed: $error');
      });
});

final chatRoomsWithDetailsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) {
    if (_dmGw) {
      return _gatewayInboxStream(ref);
    }
    return _legacyInboxStream(ref);
  },
);

Stream<List<Map<String, dynamic>>> _gatewayInboxStream(Ref ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value(const []);

  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  var last = <Map<String, dynamic>>[];
  var disposed = false;
  final hub = DmRealtimeHub.instance;

  Future<void> hydrate({String reason = 'refresh'}) async {
    await AppTelemetry.traceAsync(
      reason == 'initial' ? 'chat_inbox_hydrate' : 'chat_inbox_refresh',
      () async {
        try {
          if (last.isNotEmpty && !controller.isClosed) {
            controller.add(List.from(last));
          }

          await hub.ensureStarted();
          final rooms = await ChatService.fetchInboxDetails();
          if (disposed) return;
          final peerIds = rooms
              .map((r) => (r['other_user'] as Map?)?['id']?.toString())
              .whereType<String>()
              .toList();
          if (peerIds.isNotEmpty) {
            final online = await hub.watchUsers(peerIds);
            for (final room in rooms) {
              final other = room['other_user'];
              if (other is Map) {
                final oid = other['id']?.toString();
                if (oid != null) {
                  other['is_online'] = online[oid] == true;
                }
              }
            }
          }
          last = rooms;
          debugPrint('[DM_GW]: inbox REST $reason → ${last.length}');
          if (!controller.isClosed) controller.add(List.from(last));
        } catch (e, st) {
          await AppTelemetry.recordError(e, st, reason: 'chat_inbox_hydrate');
          debugPrint('[DM_GW]: inbox hydrate failed: $e');
          if (!controller.isClosed && last.isNotEmpty) {
            controller.add(List.from(last));
          }
        }
      },
      keys: {'reason': reason},
      slowMs: 3000,
    );
  }

  void applyPresence(Map<String, dynamic> e) {
    final uid = e['user_id']?.toString();
    if (uid == null) return;
    final online = e['online'] == true;
    var changed = false;
    last = last.map((room) {
      final other = room['other_user'];
      if (other is Map && other['id']?.toString() == uid) {
        changed = true;
        return {
          ...room,
          'other_user': {
            ...Map<String, dynamic>.from(other),
            'is_online': online,
          },
        };
      }
      return room;
    }).toList();
    if (changed && !controller.isClosed) controller.add(List.from(last));
  }

  void applyInboxPatch(Map<String, dynamic> patch) {
    final convId = patch['conversation_id']?.toString();
    if (convId == null) return;
    final idx = last.indexWhere((r) => r['id']?.toString() == convId);
    if (idx < 0) {
      unawaited(hydrate(reason: 'inbox-miss'));
      return;
    }
    final room = Map<String, dynamic>.from(last[idx]);
    if (patch['last_message_at'] != null) {
      room['last_message_at'] = patch['last_message_at'];
    }
    if (patch['status'] != null) {
      room['status'] = patch['status'];
    }
    if (patch.containsKey('unread_count')) {
      room['unread_count'] = patch['unread_count'];
    }
    final lm = patch['last_message'];
    if (lm is Map) {
      room['last_message'] = Map<String, dynamic>.from(lm);
    }
    last = [...last];
    last[idx] = room;
    last.sort((a, b) {
      final aT = (a['last_message_at'] ?? '') as String;
      final bT = (b['last_message_at'] ?? '') as String;
      return bT.compareTo(aT);
    });
    if (!controller.isClosed) controller.add(List.from(last));
  }

  unawaited(hydrate(reason: 'initial'));
  final inboxSub = hub.inboxEvents.listen(applyInboxPatch);
  final presenceSub = hub.presenceEvents.listen(applyPresence);
  final reconnectSub = Stream.periodic(const Duration(minutes: 5)).listen((_) {
    if (disposed || !_isMessagesTabActive(ref)) return;
    unawaited(hydrate(reason: 'badge-refresh'));
  });

  ref.onDispose(() {
    disposed = true;
    unawaited(inboxSub.cancel());
    unawaited(presenceSub.cancel());
    unawaited(reconnectSub.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
}

Stream<List<Map<String, dynamic>>> _legacyInboxStream(Ref ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  return ref
      .watch(conversationsProvider)
      .when(
        skipLoadingOnReload: true,
        skipError: true,
        data: (conversations) {
          if (conversations.isEmpty) return Stream.value([]);

          final roomStreams = conversations.map((room) {
            final otherId = room['participant_1_id'] == userId
                ? room['participant_2_id']
                : room['participant_1_id'];

            final userStream = supabase
                .from('users')
                .stream(primaryKey: ['id'])
                .eq('id', otherId)
                .limit(1);

            final messageStream = supabase
                .from('chat_messages')
                .stream(primaryKey: ['id'])
                .eq('conversation_id', room['id'])
                .order('created_at', ascending: false)
                .limit(1);

            final unreadStream = supabase
                .from('chat_messages')
                .stream(primaryKey: ['id'])
                .eq('conversation_id', room['id'])
                .map(
                  (msgs) => msgs
                      .where(
                        (m) =>
                            m['sender_id'] != userId && m['is_read'] == false,
                      )
                      .toList(),
                );

            final seatStream = supabase
                .from('room_seats')
                .stream(primaryKey: ['id'])
                .eq('user_id', otherId)
                .limit(1);

            final activeRoomStream = seatStream.switchMap((seats) {
              if (seats.isEmpty) {
                return Stream<Map<String, dynamic>?>.value(null);
              }
              final roomId = seats.first['room_id'];
              if (roomId == null) {
                return Stream<Map<String, dynamic>?>.value(null);
              }
              return supabase
                  .from('rooms')
                  .stream(primaryKey: ['id'])
                  .eq('id', roomId)
                  .limit(1)
                  .map((rooms) => rooms.isNotEmpty ? rooms.first : null);
            });

            return Rx.combineLatest4<
              List<Map<String, dynamic>>,
              List<Map<String, dynamic>>,
              List<Map<String, dynamic>>,
              Map<String, dynamic>?,
              Map<String, dynamic>
            >(userStream, messageStream, unreadStream, activeRoomStream, (
              users,
              messages,
              unread,
              activeRoom,
            ) {
              final userMap = users.isNotEmpty
                  ? Map<String, dynamic>.from(users.first)
                  : null;
              if (userMap != null) {
                final updatedAtStr = userMap['updated_at'];
                if (updatedAtStr != null) {
                  final updatedAt = DateTime.parse(updatedAtStr);
                  final isOnline =
                      DateTime.now().difference(updatedAt).inMinutes < 2;
                  userMap['is_online'] = isOnline;
                } else {
                  userMap['is_online'] = false;
                }
                userMap['active_room'] = activeRoom;
              }
              return {
                ...room,
                'other_user': userMap,
                'last_message': messages.isNotEmpty ? messages.first : null,
                'unread_count': unread.length,
              };
            });
          }).toList();

          return Rx.combineLatestList(
            roomStreams,
          ).debounceTime(const Duration(milliseconds: 120));
        },
        loading: () => const Stream.empty(),
        error: (e, s) {
          debugPrint('[CHAT_STREAM_ERROR]: rooms details skipped: $e');
          return const Stream.empty();
        },
      );
}

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, conversationId) {
      cacheFamilyEntry(ref, ttl: const Duration(minutes: 10));
      if (_dmGw) {
        return _gatewayMessagesStream(ref, conversationId);
      }
      return _legacyMessagesStream(ref, conversationId);
    });

Stream<List<Map<String, dynamic>>> _gatewayMessagesStream(
  Ref ref,
  String conversationId,
) {
  debugPrint('[DM_GW]: messages for conversation: $conversationId');

  final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
  var last = <Map<String, dynamic>>[];
  var disposed = false;
  final hub = DmRealtimeHub.instance;
  hub.activeConversationId = conversationId;

  void emit() {
    if (!controller.isClosed) controller.add(List.from(last));
  }

  void upsertMessage(Map<String, dynamic> msg) {
    final id = msg['id']?.toString();
    final tempId = _tempIdOf(msg);
    var idx = -1;
    if (id != null) {
      idx = last.indexWhere((m) => m['id']?.toString() == id);
    }
    if (idx < 0 && tempId != null) {
      idx = last.indexWhere((m) => _tempIdOf(m) == tempId);
    }
    if (idx >= 0) {
      last = [...last];
      last[idx] = {...last[idx], ...msg};
    } else {
      last = [msg, ...last];
    }
    last.sort((a, b) {
      final aT = (a['created_at'] ?? '') as String;
      final bT = (b['created_at'] ?? '') as String;
      return bT.compareTo(aT);
    });
    if (last.length > AppConstants.dmHydrateLimit + 50) {
      last = last.take(AppConstants.dmHydrateLimit + 50).toList();
    }
    emit();
  }

  Future<void> loadOnce({String reason = 'refresh'}) async {
    await AppTelemetry.traceAsync(
      'chat_messages_hydrate',
      () async {
        try {
          final data = await supabase
              .from('chat_messages')
              .select()
              .eq('conversation_id', conversationId)
              .order('created_at', ascending: false)
              .limit(AppConstants.dmHydrateLimit);
          if (disposed) return;
          last = List<Map<String, dynamic>>.from(data as List);
          debugPrint('[DM_GW]: REST $reason → ${last.length}');
          emit();
        } catch (e, st) {
          await AppTelemetry.recordError(
            e,
            st,
            reason: 'chat_messages_hydrate',
            keys: {'conversation_id': conversationId},
          );
          debugPrint('[DM_GW]: REST fetch failed: $e');
          if (!controller.isClosed && last.isNotEmpty) emit();
        }
      },
      keys: {'conversation_id': conversationId, 'reason': reason},
      slowMs: 3000,
    );
  }

  unawaited(() async {
    await hub.ensureStarted();
    await loadOnce(reason: 'initial');
    final newest = last.isNotEmpty
        ? last.first['created_at']?.toString()
        : null;
    if (newest != null) {
      await hub.syncConversation(conversationId, afterTs: newest);
    }
  }());

  final msgSub = hub.messageEvents.listen((event) {
    if (event['conversation_id']?.toString() != conversationId) return;
    final message = event['message'];
    if (message is Map) {
      upsertMessage(Map<String, dynamic>.from(message));
    }
  });

  final readSub = hub.readEvents.listen((event) {
    if (event['conversation_id']?.toString() != conversationId) return;
    final ids =
        (event['message_ids'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    if (ids.isEmpty) {
      final myId = supabase.auth.currentUser?.id;
      last = last.map((m) {
        if (m['sender_id'] != myId) {
          return {...m, 'is_read': true};
        }
        return m;
      }).toList();
    } else {
      last = last.map((m) {
        if (ids.contains(m['id']?.toString())) {
          return {...m, 'is_read': true};
        }
        return m;
      }).toList();
    }
    emit();
  });

  ref.onDispose(() {
    disposed = true;
    if (hub.activeConversationId == conversationId) {
      hub.activeConversationId = null;
    }
    unawaited(msgSub.cancel());
    unawaited(readSub.cancel());
    unawaited(controller.close());
  });

  return controller.stream;
}

Stream<List<Map<String, dynamic>>> _legacyMessagesStream(
  Ref ref,
  String conversationId,
) {
  debugPrint(
    '[CHAT_STREAM]: Starting messages stream for conversation: $conversationId',
  );

  return supabase
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: false)
      .map((data) {
        debugPrint(
          '[CHAT_STREAM]: Received ${data.length} messages for $conversationId',
        );
        return data;
      })
      .handleError((error) {
        debugPrint('[CHAT_STREAM_ERROR]: Messages stream failed: $error');
      });
}

String? _tempIdOf(Map<String, dynamic> msg) {
  final meta = msg['metadata'];
  if (meta is Map) return meta['temp_id']?.toString();
  return null;
}

final conversationDetailProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, conversationId) {
      if (_dmGw) {
        final controller = StreamController<Map<String, dynamic>?>.broadcast();
        var disposed = false;

        Future<void> load() async {
          try {
            final row = await supabase
                .from('conversations')
                .select()
                .eq('id', conversationId)
                .maybeSingle();
            if (!disposed && !controller.isClosed) {
              controller.add(row);
            }
          } catch (e) {
            debugPrint('[DM_GW]: conversation detail failed: $e');
          }
        }

        unawaited(load());
        final tick = Stream.periodic(const Duration(seconds: 20)).listen((_) {
          if (!disposed) unawaited(load());
        });

        ref.onDispose(() {
          disposed = true;
          unawaited(tick.cancel());
          unawaited(controller.close());
        });
        return controller.stream;
      }

      return supabase
          .from('conversations')
          .stream(primaryKey: ['id'])
          .eq('id', conversationId)
          .limit(1)
          .map((data) => data.isNotEmpty ? data.first : null);
    });

final userStatusProvider = StreamProvider.family<Map<String, dynamic>?, String>(
  (ref, userId) {
    if (_dmGw) {
      final controller = StreamController<Map<String, dynamic>?>.broadcast();
      var disposed = false;
      final hub = DmRealtimeHub.instance;

      void emit(bool online) {
        if (disposed || controller.isClosed) return;
        controller.add({
          'id': userId,
          'is_online': online,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      unawaited(() async {
        await hub.ensureStarted();
        final map = await hub.watchUsers([userId]);
        emit(map[userId] == true || hub.isOnlineCached(userId) == true);
      }());

      final sub = hub.presenceEvents.listen((e) {
        if (e['user_id']?.toString() != userId) return;
        emit(e['online'] == true);
      });

      ref.onDispose(() {
        disposed = true;
        unawaited(sub.cancel());
        unawaited(controller.close());
      });
      return controller.stream;
    }

    return supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .limit(1)
        .map((data) => data.isNotEmpty ? data.first : null);
  },
);

class ChatService {
  static Future<List<Map<String, dynamic>>> fetchInboxDetails() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    await DmRealtimeHub.instance.ensureStarted();
    final ack = await RoomRealtimeSocket.instance.dmInboxSync({'limit': 100});
    List<Map<String, dynamic>> rows = [];
    if (ack != null && ack['ok'] == true && ack['conversations'] is List) {
      rows = (ack['conversations'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } else {
      debugPrint('[DM_GW]: inbox_sync fallback to REST: ${ack?['error']}');
      return _fetchInboxDetailsRest(userId);
    }

    final otherIds = rows
        .map((r) => r['other_user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> activeRooms = {};
    if (otherIds.isNotEmpty) {
      try {
        final seats = await supabase
            .from('room_seats')
            .select('user_id, room_id')
            .inFilter('user_id', otherIds);
        final roomIds = (seats as List)
            .map((s) => s['room_id']?.toString())
            .whereType<String>()
            .toSet()
            .toList();
        if (roomIds.isNotEmpty) {
          final rooms = await supabase
              .from('rooms')
              .select('id, title, image_url, is_active, host_id')
              .inFilter('id', roomIds);
          final roomsById = {
            for (final r in (rooms as List))
              r['id'] as String: Map<String, dynamic>.from(r as Map),
          };
          for (final s in seats) {
            final uid = s['user_id']?.toString();
            final rid = s['room_id']?.toString();
            if (uid == null || rid == null) continue;
            final room = roomsById[rid];
            if (room != null && room['is_active'] == true) {
              activeRooms[uid] = room;
            }
          }
        }
      } catch (e) {
        debugPrint('[DM_GW]: live badge fetch: $e');
      }
    }

    return rows.map((r) {
      final otherId = r['other_user_id']?.toString();
      final updatedAtStr = r['other_updated_at'];
      bool isOnline = false;
      if (updatedAtStr != null) {
        final updatedAt = DateTime.tryParse(updatedAtStr.toString());
        isOnline =
            updatedAt != null &&
            DateTime.now().difference(updatedAt).inMinutes < 2;
      }
      final otherUser = <String, dynamic>{
        'id': otherId,
        'username': r['other_username'],
        'avatar_url': r['other_avatar_url'],
        'updated_at': r['other_updated_at'],
        'short_id': r['other_short_id'],
        'is_online': isOnline,
        'active_room': otherId != null ? activeRooms[otherId] : null,
      };
      Map<String, dynamic>? lastMessage;
      if (r['last_message_id'] != null) {
        lastMessage = {
          'id': r['last_message_id'],
          'content': r['last_message_content'],
          'message_type': r['last_message_type'],
          'media_url': r['last_message_media_url'],
          'sender_id': r['last_message_sender_id'],
          'created_at': r['last_message_created_at'],
          'metadata': r['last_message_metadata'],
        };
      }
      return {
        'id': r['id'],
        'participant_1_id': r['participant_1_id'],
        'participant_2_id': r['participant_2_id'],
        'status': r['status'],
        'last_message_at': r['last_message_at'],
        'created_at': r['created_at'],
        'other_user': otherUser,
        'last_message': lastMessage,
        'unread_count': r['unread_count'] ?? 0,
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchInboxDetailsRest(
    String userId,
  ) async {
    final convs = await supabase
        .from('conversations')
        .select()
        .or('participant_1_id.eq.$userId,participant_2_id.eq.$userId')
        .order('last_message_at', ascending: false)
        .limit(100);

    final list = List<Map<String, dynamic>>.from(convs as List);
    if (list.isEmpty) return [];

    final otherIds = <String>[];
    final convIds = <String>[];
    for (final room in list) {
      final cid = room['id']?.toString();
      if (cid != null) convIds.add(cid);
      final otherId = room['participant_1_id'] == userId
          ? room['participant_2_id']
          : room['participant_1_id'];
      final oid = otherId?.toString();
      if (oid != null && oid.isNotEmpty) otherIds.add(oid);
    }

    final usersById = <String, Map<String, dynamic>>{};
    if (otherIds.isNotEmpty) {
      final users = await supabase
          .from('users')
          .select('id, username, avatar_url, updated_at, short_id')
          .inFilter('id', otherIds.toSet().toList());
      for (final u in (users as List)) {
        final id = u['id']?.toString();
        if (id == null) continue;
        final other = Map<String, dynamic>.from(u as Map);
        final updatedAtStr = other['updated_at'];
        if (updatedAtStr != null) {
          final updatedAt = DateTime.tryParse(updatedAtStr.toString());
          other['is_online'] =
              updatedAt != null &&
              DateTime.now().difference(updatedAt).inMinutes < 2;
        }
        usersById[id] = other;
      }
    }

    final lastByConv = <String, Map<String, dynamic>>{};
    if (convIds.isNotEmpty) {
      try {
        final msgs = await supabase
            .from('chat_messages')
            .select(
              'conversation_id, id, content, message_type, media_url, sender_id, created_at, metadata',
            )
            .inFilter('conversation_id', convIds)
            .order('created_at', ascending: false)
            .limit(convIds.length * 5 < 100 ? 100 : convIds.length * 5);
        for (final row in (msgs as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          final cid = m['conversation_id']?.toString();
          if (cid != null) lastByConv.putIfAbsent(cid, () => m);
        }
      } catch (e) {
        debugPrint('[DM_GW]: last-message batch failed: $e');
      }
    }

    return list.map((room) {
      final otherId = room['participant_1_id'] == userId
          ? room['participant_2_id']?.toString()
          : room['participant_1_id']?.toString();
      final cid = room['id']?.toString();
      return {
        ...room,
        'other_user': otherId != null ? usersById[otherId] : null,
        'last_message': cid != null ? lastByConv[cid] : null,
        'unread_count': 0,
      };
    }).toList();
  }

  static Future<String> getOrCreateConversation(String targetId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) throw 'User not authenticated';

    final ids = [currentUserId, targetId]..sort();
    final p1 = ids[0];
    final p2 = ids[1];

    try {
      final targetProfile = await supabase
          .from('users')
          .select('vip_level')
          .eq('id', targetId)
          .single();

      final int vipLevel = (targetProfile['vip_level'] as num?)?.toInt() ?? 0;
      if (vipLevel > 0) {
        final vipPlan = await supabase
            .from('vip_plans')
            .select('has_refuse_strangers')
            .eq('level', vipLevel)
            .maybeSingle();

        if (vipPlan != null && vipPlan['has_refuse_strangers'] == true) {
          final followCheck = await supabase
              .from('follows')
              .select('id')
              .eq('follower_id', targetId)
              .eq('following_id', currentUserId)
              .maybeSingle();

          if (followCheck == null) {
            throw 'Privacy Shield: This user only accepts messages from friends.';
          }
        }
      }

      final response = await supabase
          .from('conversations')
          .select()
          .eq('participant_1_id', p1)
          .eq('participant_2_id', p2)
          .maybeSingle();

      if (response != null) {
        return response['id'];
      }

      final newConv = await supabase
          .from('conversations')
          .insert({
            'participant_1_id': p1,
            'participant_2_id': p2,
            'status': 'accepted',
          })
          .select()
          .single();

      return newConv['id'];
    } catch (e) {
      debugPrint('CHAT_DEBUG: Error getOrCreateConversation: $e');
      rethrow;
    }
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String type,
    String? content,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (_dmGw) {
        await DmRealtimeHub.instance.sendMessage(
          conversationId: conversationId,
          type: type,
          content: content,
          mediaUrl: mediaUrl,
          metadata: metadata,
        );
        return;
      }

      await supabase.from('chat_messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'content': content,
        'message_type': type,
        'media_url': mediaUrl,
        'metadata': metadata ?? {},
      });

      await Future.wait([
        supabase
            .from('conversations')
            .update({'last_message_at': DateTime.now().toIso8601String()})
            .eq('id', conversationId),
        supabase
            .from('users')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId),
      ]);
    } catch (e) {
      debugPrint('CHAT_DEBUG: Error sending message: $e');
      rethrow;
    }
  }

  static Future<void> acceptRequest(String conversationId) async {
    await supabase
        .from('conversations')
        .update({'status': 'accepted'})
        .eq('id', conversationId);
  }

  static Future<void> blockConversation(String conversationId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final conv = await supabase
          .from('conversations')
          .select('participant_1_id, participant_2_id')
          .eq('id', conversationId)
          .single();

      final targetId = conv['participant_1_id'] == userId
          ? conv['participant_2_id']
          : conv['participant_1_id'];

      final targetProfile = await supabase
          .from('users')
          .select('vip_level')
          .eq('id', targetId)
          .single();

      final int vipLevel = (targetProfile['vip_level'] as num?)?.toInt() ?? 0;
      if (vipLevel > 0) {
        final vipPlan = await supabase
            .from('vip_plans')
            .select('has_anti_blocking')
            .eq('level', vipLevel)
            .maybeSingle();
        if (vipPlan != null && vipPlan['has_anti_blocking'] == true) {
          throw 'This user is protected by Anti-Blocking privilege.';
        }
      }

      await supabase
          .from('conversations')
          .update({'status': 'blocked', 'blocked_by': userId})
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('CHAT_DEBUG: Block conversation error: $e');
      rethrow;
    }
  }

  static Future<void> unblockConversation(String conversationId) async {
    await supabase
        .from('conversations')
        .update({'status': 'accepted', 'blocked_by': null})
        .eq('id', conversationId);
  }

  static Future<void> reportUser({
    required String targetId,
    required String reason,
    String? conversationId,
    String? details,
  }) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    await supabase.from('user_reports').insert({
      'reporter_id': myId,
      'target_id': targetId,
      'conversation_id': conversationId,
      'reason': reason,
      'details': details,
    });
  }

  static Future<String?> uploadMedia(File file, String path) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final fileName = const Uuid().v4();
      final extension = file.path.split('.').last;
      final fullPath = '$userId/$path/$fileName.$extension';

      await supabase.storage.from('chat_assets').upload(fullPath, file);
      return supabase.storage.from('chat_assets').getPublicUrl(fullPath);
    } catch (e) {
      debugPrint('CHAT_DEBUG: Media upload error: $e');
      return null;
    }
  }

  static Future<void> deleteMessage(String messageId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('chat_messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', userId);
    } catch (e) {
      debugPrint('CHAT_DEBUG: Error deleting message: $e');
      rethrow;
    }
  }

  static Future<void> markAsRead(String conversationId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (_dmGw) {
      await DmRealtimeHub.instance.markRead(conversationId);
      return;
    }

    await supabase
        .from('chat_messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }
}
