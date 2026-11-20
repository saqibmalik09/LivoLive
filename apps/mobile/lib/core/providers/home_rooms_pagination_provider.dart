import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/room_sort_utils.dart';

enum RoomListSort { popular, newest }

class PaginatedRoomsState {
  const PaginatedRoomsState({
    this.rooms = const [],
    this.giftTotals = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.sort = RoomListSort.popular,
  });

  final List<Map<String, dynamic>> rooms;
  final Map<String, int> giftTotals;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final RoomListSort sort;

  PaginatedRoomsState copyWith({
    List<Map<String, dynamic>>? rooms,
    Map<String, int>? giftTotals,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    RoomListSort? sort,
    bool clearError = false,
  }) {
    return PaginatedRoomsState(
      rooms: rooms ?? this.rooms,
      giftTotals: giftTotals ?? this.giftTotals,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      sort: sort ?? this.sort,
    );
  }
}

const _firstPageSize = 24;
const _pageSize = 16;

// Explicit projection instead of select('*'). Covers every field the room
// list cards (home_ref_room_card.dart, party_screen.dart card builders,
// room_sort_utils.dart) read, plus every field RoomLiveScreen reads straight
// off the tapped room map (widget.room/_roomData) for its first paint before
// its own fresh fetch lands — background_url/mic_count/party_mode/etc. Omit
// anything here and that first paint silently loses that field for one
// round-trip, which is exactly the entry-lag symptom this plan targets.
// Columns intentionally still left out (truly unused by any of the above):
// theme, is_active, is_private, membership_tag_name/color, host_short_id,
// host_vip_level, has_room_priority, current_rank, ranking_type, rank_badge,
// rank_frame.
const roomListColumns =
    'id, short_id, host_id, title, room_password, is_locked, created_at, '
    'room_topic, image_url, announcement, country_code, decoration_id, '
    'mic_count, party_mode, background_url, youtube_state, '
    'online_users_count, seated_users_count, chat_cleared_at, '
    'admin_only_chat, is_pinned, pin_order, host_name, host_avatar, '
    'host_country_code, ranking_score, top_avatars';

Future<List<Map<String, dynamic>>> _fetchRoomsPage({
  required int offset,
  required int limit,
  required RoomListSort sort,
  String? countryCode,
  String? topicSlug,
}) async {
  final supabase = Supabase.instance.client;

  dynamic query;
  if (countryCode != null && countryCode.isNotEmpty) {
    query = supabase
        .from('active_rooms_with_rankings')
        .select(
          '$roomListColumns, '
          'host:host_id!inner(username, avatar_url, country_code, short_id)',
        )
        .eq('host.country_code', countryCode);
  } else {
    query = supabase
        .from('active_rooms_with_rankings')
        .select(roomListColumns);
  }

  if (topicSlug != null && topicSlug.isNotEmpty) {
    query = query.eq('room_topic', topicSlug);
  }

  if (sort == RoomListSort.popular) {
    query = query
        .order('seated_users_count', ascending: false)
        .order('online_users_count', ascending: false)
        .order('ranking_score', ascending: false)
        // Deterministic final key. ranking_score is 0 for every room today and
        // most rooms sit at one seated / one online, so without this the vast
        // majority of rooms tie on every sort key and Postgres is free to
        // return them in a different order each query — a room that lost its
        // pin appeared in a different place on every refresh.
        .order('created_at', ascending: false)
        .order('id', ascending: true);
  } else {
    query = query
        .order('created_at', ascending: false)
        .order('id', ascending: true);
  }

  final response = await query.range(offset, offset + limit - 1);

  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final room in response as List) {
    final map = Map<String, dynamic>.from(room as Map);
    final id = map['id']?.toString();
    if (id == null || seen.contains(id)) continue;
    seen.add(id);
    unique.add(map);
  }
  if (sort == RoomListSort.popular) {
    sortRoomsByPopularRanking(unique);
  }
  return unique;
}

Future<Map<String, int>> _fetchGiftTotalsForRooms(
  List<Map<String, dynamic>> rooms,
) async {
  final ids = <String>[];
  for (final room in rooms) {
    final id = room['id']?.toString();
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  if (ids.isEmpty) return {};

  try {
    final response = await Supabase.instance.client.rpc(
      'get_rooms_recent_gift_totals',
      params: {'p_room_ids': ids, 'p_minutes': 30},
    );

    final map = <String, int>{};
    for (final row in (response as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['room_id']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = (m['total'] as num?)?.toInt() ?? 0;
    }
    return map;
  } catch (e) {
    debugPrint('[RoomsGiftTotals] fetch failed: $e');
    return {};
  }
}

class DiscoveryRoomsNotifier extends Notifier<PaginatedRoomsState> {
  int _offset = 0;
  bool _fetching = false;

  @override
  PaginatedRoomsState build() {
    final cached = HiveCacheService.loadRoomCovers();
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(() => loadInitial(silentIfCached: true));
      return PaginatedRoomsState(
        rooms: cached,
        hasMore: true,
        isLoading: false,
      );
    }
    Future.microtask(loadInitial);
    return const PaginatedRoomsState(isLoading: true);
  }

  Future<void> setSort(RoomListSort sort) async {
    if (state.sort == sort && state.rooms.isNotEmpty) return;
    state = state.copyWith(sort: sort);
    await loadInitial();
  }

  Future<void> loadInitial({bool silentIfCached = false}) async {
    if (_fetching) return;
    _fetching = true;
    _offset = 0;
    final keepCachedPaint =
        silentIfCached && state.rooms.isNotEmpty && !state.isLoading;
    if (!keepCachedPaint) {
      state = PaginatedRoomsState(isLoading: true, sort: state.sort);
    }

    try {
      final page = await _fetchRoomsPage(
        offset: 0,
        limit: _firstPageSize,
        sort: state.sort,
      );
      _offset = page.length;
      // Paint the page immediately. Gift totals are a second, separate RPC
      // (get_rooms_recent_gift_totals) — waiting on it before the first
      // commit added a full extra round-trip before anything could render.
      state = PaginatedRoomsState(
        rooms: page,
        hasMore: page.length >= _firstPageSize,
        sort: state.sort,
      );
      _maybeUpdateRoomCoversCache(page, state.sort);
      final gifts = await _fetchGiftTotalsForRooms(page);
      if (identical(state.rooms, page)) {
        state = state.copyWith(giftTotals: gifts);
      }
    } catch (e, st) {
      debugPrint('[DiscoveryRooms] loadInitial: $e\n$st');
      if (!keepCachedPaint || state.rooms.isEmpty) {
        state = PaginatedRoomsState(error: e, sort: state.sort);
      }
    } finally {
      _fetching = false;
    }
  }

  void _maybeUpdateRoomCoversCache(
    List<Map<String, dynamic>> rooms,
    RoomListSort sort,
  ) {
    if (sort != RoomListSort.popular) return;
    HiveCacheService.saveRoomCovers(rooms).ignore();
  }

  Future<void> loadMore() async {
    if (_fetching || state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }
    _fetching = true;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _fetchRoomsPage(
        offset: _offset,
        limit: _pageSize,
        sort: state.sort,
      );
      _offset += page.length;

      final seen = state.rooms.map((r) => r['id']?.toString()).toSet();
      final merged = List<Map<String, dynamic>>.from(state.rooms);
      final newRooms = <Map<String, dynamic>>[];
      for (final room in page) {
        final id = room['id']?.toString();
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        merged.add(room);
        newRooms.add(room);
      }

      // Paint the merged page immediately; gift totals for the new rooms
      // follow as a second, narrower update instead of gating first paint.
      state = state.copyWith(
        rooms: merged,
        hasMore: page.length >= _pageSize,
        isLoadingMore: false,
        clearError: true,
      );

      final pageGifts = await _fetchGiftTotalsForRooms(newRooms);
      if (pageGifts.isNotEmpty && identical(state.rooms, merged)) {
        state = state.copyWith(
          giftTotals: {...state.giftTotals, ...pageGifts},
        );
      }
    } catch (e, st) {
      debugPrint('[DiscoveryRooms] loadMore: $e\n$st');
      state = state.copyWith(isLoadingMore: false, error: e);
    } finally {
      _fetching = false;
    }
  }

  Future<void> refresh() => loadInitial();
}

class CountryRoomsNotifier extends Notifier<PaginatedRoomsState> {
  int _offset = 0;
  bool _fetching = false;
  String _countryCode = '';
  String? _topicSlug;

  @override
  PaginatedRoomsState build() => const PaginatedRoomsState();

  void configure({required String countryCode, String? topicSlug}) {
    final normalized = countryCode.trim();
    if (normalized.isEmpty) return;
    if (_countryCode == normalized &&
        _topicSlug == topicSlug &&
        (state.rooms.isNotEmpty || state.isLoading)) {
      return;
    }
    _countryCode = normalized;
    _topicSlug = topicSlug;
    unawaited(loadInitial());
  }

  Future<void> loadInitial() async {
    if (_countryCode.isEmpty || _fetching) return;
    _fetching = true;
    _offset = 0;
    state = const PaginatedRoomsState(isLoading: true);

    try {
      final page = await _fetchRoomsPage(
        offset: 0,
        limit: _firstPageSize,
        sort: RoomListSort.popular,
        countryCode: _countryCode,
        topicSlug: _topicSlug,
      );
      _offset = page.length;
      state = PaginatedRoomsState(
        rooms: page,
        hasMore: page.length >= _firstPageSize,
        sort: RoomListSort.popular,
      );
      final gifts = await _fetchGiftTotalsForRooms(page);
      if (identical(state.rooms, page)) {
        state = state.copyWith(giftTotals: gifts);
      }
    } catch (e, st) {
      debugPrint('[CountryRooms] loadInitial: $e\n$st');
      state = PaginatedRoomsState(error: e);
    } finally {
      _fetching = false;
    }
  }

  Future<void> loadMore() async {
    if (_countryCode.isEmpty ||
        _fetching ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    _fetching = true;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _fetchRoomsPage(
        offset: _offset,
        limit: _pageSize,
        sort: RoomListSort.popular,
        countryCode: _countryCode,
        topicSlug: _topicSlug,
      );
      _offset += page.length;

      final seen = state.rooms.map((r) => r['id']?.toString()).toSet();
      final merged = List<Map<String, dynamic>>.from(state.rooms);
      final newRooms = <Map<String, dynamic>>[];
      for (final room in page) {
        final id = room['id']?.toString();
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        merged.add(room);
        newRooms.add(room);
      }

      state = state.copyWith(
        rooms: merged,
        hasMore: page.length >= _pageSize,
        isLoadingMore: false,
        clearError: true,
      );

      final pageGifts = await _fetchGiftTotalsForRooms(newRooms);
      if (pageGifts.isNotEmpty && identical(state.rooms, merged)) {
        state = state.copyWith(
          giftTotals: {...state.giftTotals, ...pageGifts},
        );
      }
    } catch (e, st) {
      debugPrint('[CountryRooms] loadMore: $e\n$st');
      state = state.copyWith(isLoadingMore: false, error: e);
    } finally {
      _fetching = false;
    }
  }

  Future<void> refresh() => loadInitial();
}

final discoveryRoomsPaginationProvider =
    NotifierProvider<DiscoveryRoomsNotifier, PaginatedRoomsState>(
      DiscoveryRoomsNotifier.new,
    );

final countryRoomsPaginationProvider =
    NotifierProvider<CountryRoomsNotifier, PaginatedRoomsState>(
      CountryRoomsNotifier.new,
    );
