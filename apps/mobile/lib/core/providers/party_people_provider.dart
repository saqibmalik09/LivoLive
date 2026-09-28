import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'package:sk_live/core/services/app_telemetry.dart';

class PartyProfileEntry {
  const PartyProfileEntry({
    required this.user,
    this.roomTitle,
    this.roomId,
    this.room,
  });

  final Map<String, dynamic> user;
  final String? roomTitle;
  final String? roomId;
  final Map<String, dynamic>? room;

  String get userId => user['id']?.toString() ?? '';
  String get username => user['username']?.toString() ?? 'User';
  String? get avatarUrl => user['avatar_url']?.toString();
  String get bio => user['bio']?.toString().trim() ?? '';

  List<String> get coverImages {
    final raw = user['cover_images'];
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    }
    return [];
  }

  bool get hasProfileContent => bio.isNotEmpty || coverImages.isNotEmpty;
}

List<String> _parseCoverImages(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

bool _userHasPartyContent(Map<String, dynamic> user) {
  final bio = user['bio']?.toString().trim() ?? '';
  final covers = _parseCoverImages(user['cover_images']);
  return bio.isNotEmpty || covers.isNotEmpty;
}

Map<String, dynamic> _userRow(Map<String, dynamic> row) {
  return Map<String, dynamic>.from(row);
}

const _userSelect = 'id, username, avatar_url, bio, cover_images, updated_at';

Future<Map<String, dynamic>?> fetchRoomForUser(String userId) async {
  final supabase = Supabase.instance.client;

  final hosted = await supabase
      .from('rooms')
      .select('*, room_stats(*)')
      .eq('host_id', userId)
      .order('online_users_count', ascending: false)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (hosted != null) return Map<String, dynamic>.from(hosted);

  final seat = await supabase
      .from('room_seats')
      .select('room_id')
      .eq('user_id', userId)
      .limit(1)
      .maybeSingle();
  final roomId = seat?['room_id']?.toString();
  if (roomId == null) return null;

  final seatedRoom = await supabase
      .from('rooms')
      .select('*, room_stats(*)')
      .eq('id', roomId)
      .maybeSingle();
  if (seatedRoom == null) return null;
  return Map<String, dynamic>.from(seatedRoom);
}

final partyPeopleProvider = FutureProvider.autoDispose<List<PartyProfileEntry>>(
  (ref) async {
    cacheFamilyEntry(ref);
    return AppTelemetry.traceAsync(
      'party_feed_load',
      () async {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('users')
            .select(_userSelect)
            .order('updated_at', ascending: false)
            .limit(80);

        final entries = <PartyProfileEntry>[];
        for (final row in response) {
          final user = _userRow(row);
          if (_userHasPartyContent(user)) {
            entries.add(PartyProfileEntry(user: user));
            if (entries.length >= 40) break;
          }
        }
        return entries;
      },
      keys: {'filter': 'people'},
      slowMs: 3000,
    );
  },
);

final partyFollowingProvider =
    FutureProvider.autoDispose<List<PartyProfileEntry>>((ref) async {
      cacheFamilyEntry(ref);
      return AppTelemetry.traceAsync(
        'party_feed_load',
        () async {
          final supabase = Supabase.instance.client;
          final userId = supabase.auth.currentUser?.id;
          if (userId == null) return <PartyProfileEntry>[];

          final follows = await supabase
              .from('follows')
              .select('following_id')
              .eq('follower_id', userId)
              .limit(100);
          final ids = (follows as List)
              .map((f) => f['following_id']?.toString())
              .whereType<String>()
              .toList();
          if (ids.isEmpty) return <PartyProfileEntry>[];

          final response = await supabase
              .from('users')
              .select(_userSelect)
              .inFilter('id', ids)
              .order('updated_at', ascending: false)
              .limit(100);

          return (response as List)
              .map(
                (row) => PartyProfileEntry(
                  user: _userRow(row as Map<String, dynamic>),
                ),
              )
              .toList();
        },
        keys: {'filter': 'following'},
        slowMs: 3000,
      );
    });

final partyJoinedProvider = FutureProvider.autoDispose<List<PartyProfileEntry>>(
  (ref) async {
    cacheFamilyEntry(ref);
    return AppTelemetry.traceAsync(
      'party_feed_load',
      () async {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) return <PartyProfileEntry>[];

        final myRooms = await supabase
            .from('room_members')
            .select('room_id')
            .eq('user_id', userId)
            .limit(50);
        final roomIds = (myRooms as List)
            .map((r) => r['room_id']?.toString())
            .whereType<String>()
            .take(50)
            .toList();
        if (roomIds.isEmpty) return <PartyProfileEntry>[];

        final members = await supabase
            .from('room_members')
            .select('user_id')
            .inFilter('room_id', roomIds)
            .neq('user_id', userId)
            .limit(200);

        final memberIds = <String>{};
        for (final m in members as List) {
          final id = m['user_id']?.toString();
          if (id != null) memberIds.add(id);
          if (memberIds.length >= 200) break;
        }
        if (memberIds.isEmpty) return <PartyProfileEntry>[];

        final response = await supabase
            .from('users')
            .select(_userSelect)
            .inFilter('id', memberIds.take(200).toList())
            .order('updated_at', ascending: false)
            .limit(200);

        return (response as List)
            .map(
              (row) => PartyProfileEntry(
                user: _userRow(row as Map<String, dynamic>),
              ),
            )
            .toList();
      },
      keys: {'filter': 'joined'},
      slowMs: 3000,
    );
  },
);

final partyRecentlyProvider =
    FutureProvider.autoDispose<List<PartyProfileEntry>>((ref) async {
      cacheFamilyEntry(ref);
      return AppTelemetry.traceAsync(
        'party_feed_load',
        () async {
          final supabase = Supabase.instance.client;
          final response = await supabase
              .from('rooms')
              .select('id, title, created_at, host:host_id($_userSelect)')
              .order('created_at', ascending: false)
              .limit(40);

          final seenHosts = <String>{};
          final entries = <PartyProfileEntry>[];

          for (final row in response as List) {
            final map = Map<String, dynamic>.from(row as Map);
            final hostRaw = map['host'];
            if (hostRaw == null) continue;
            final host = _userRow(hostRaw as Map<String, dynamic>);
            final hostId = host['id']?.toString();
            if (hostId == null || seenHosts.contains(hostId)) continue;
            seenHosts.add(hostId);

            entries.add(
              PartyProfileEntry(
                user: host,
                roomTitle: map['title']?.toString(),
                roomId: map['id']?.toString(),
              ),
            );
          }
          return entries;
        },
        keys: {'filter': 'recently'},
        slowMs: 3000,
      );
    });

final partyFeaturedUserProvider =
    FutureProvider.autoDispose<PartyProfileEntry?>((ref) async {
      cacheFamilyEntry(ref);
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return null;

      final user = await supabase
          .from('users')
          .select(_userSelect)
          .eq('id', uid)
          .maybeSingle();
      if (user == null) return null;

      final room = await fetchRoomForUser(uid);
      return PartyProfileEntry(
        user: Map<String, dynamic>.from(user),
        roomTitle: room?['title']?.toString(),
        roomId: room?['id']?.toString(),
        room: room,
      );
    });
