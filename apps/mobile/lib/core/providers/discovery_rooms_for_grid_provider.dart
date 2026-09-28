import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart';

bool _isPinnedRoom(Map<String, dynamic> room) => room['is_pinned'] == true;

List<Map<String, dynamic>> _unpinnedRooms(List<Map<String, dynamic>> rooms) {
  return rooms.where((r) => !_isPinnedRoom(r)).toList(growable: false);
}

final discoveryRoomsForGridProvider = Provider<List<Map<String, dynamic>>>((
  ref,
) {
  final rooms = _unpinnedRooms(
    ref.watch(discoveryRoomsPaginationProvider.select((s) => s.rooms)),
  );
  if (rooms.length <= 3) return const [];
  return rooms.skip(3).toList(growable: false);
});

final discoveryTop3RoomsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final rooms = _unpinnedRooms(
    ref.watch(discoveryRoomsPaginationProvider.select((s) => s.rooms)),
  );
  if (rooms.isEmpty) return const [];
  return rooms.take(3).toList(growable: false);
});
