import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart';
import 'package:sk_live/core/providers/pinned_party_rooms_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const homeRoomRankingKey = ('Room', 'Day');

bool _isPinnedRoom(Map<String, dynamic> room) => room['is_pinned'] == true;

String _idOf(Map<String, dynamic> room) => room['id']?.toString() ?? '';

List<String> _rankedRoomIds(List<GiftRankingModel> ranking) {
  final seen = <String>{};
  return [
    for (final m in ranking)
      if (m.userId.trim().isNotEmpty && seen.add(m.userId.trim()))
        m.userId.trim(),
  ];
}

final homeRankedActiveRoomsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final ranking = await ref.watch(
        rankingsProvider(homeRoomRankingKey).future,
      );
      final ids = _rankedRoomIds(ranking);
      if (ids.isEmpty) return const [];
      final rows = await Supabase.instance.client
          .from('active_rooms_with_rankings')
          .select(roomListColumns)
          .inFilter('id', ids);
      final byId = <String, Map<String, dynamic>>{};
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final id = _idOf(map);
        if (id.isNotEmpty) byId.putIfAbsent(id, () => map);
      }
      return [
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
    });

final homeTop3RankedRoomsProvider = Provider<List<Map<String, dynamic>?>>((
  ref,
) {
  final ranking =
      ref.watch(rankingsProvider(homeRoomRankingKey)).valueOrNull ?? const [];
  final open = {
    for (final r
        in ref.watch(homeRankedActiveRoomsProvider).valueOrNull ?? const [])
      _idOf(r): r,
  };
  final top = <Map<String, dynamic>?>[];
  final seen = <String>{};
  for (final m in ranking) {
    if (top.length == 3) break;
    final id = m.userId.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    top.add(
      open[id] ?? {'id': id, 'title': m.username, 'image_url': m.avatarUrl},
    );
  }
  while (top.length < 3) {
    top.add(null);
  }
  return top;
});

final discoveryRoomsForGridProvider = Provider<List<Map<String, dynamic>>>((
  ref,
) {
  final listed = ref.watch(
    discoveryRoomsPaginationProvider.select((s) => s.rooms),
  );
  final bySlot = ref.watch(pinnedPartyRoomsProvider).valueOrNull;
  final pinned = bySlot == null ? null : (bySlot[1] ?? bySlot[2] ?? bySlot[3]);

  final out = <Map<String, dynamic>>[];
  final used = <String>{};
  if (pinned != null && _idOf(pinned).isNotEmpty) {
    out.add(pinned);
    used.add(_idOf(pinned));
  }
  for (final room in listed) {
    final id = _idOf(room);
    if (id.isEmpty || _isPinnedRoom(room) || !used.add(id)) continue;
    out.add(room);
  }
  return out;
});
