import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentRoomsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  static const _key = 'recent_rooms_list';
  static const _maxItems = 15;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addRoom(Map<String, dynamic> room) async {
    if (room['id'] == null) return;

    final currentList = state.value ?? [];

    final newList = currentList.where((r) => r['id'] != room['id']).toList();

    newList.insert(0, room);

    if (newList.length > _maxItems) {
      newList.removeRange(_maxItems, newList.length);
    }

    state = AsyncValue.data(newList);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(newList));
  }

  Future<void> clearRecent() async {
    state = const AsyncValue.data([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final recentRoomsProvider =
    AsyncNotifierProvider<RecentRoomsNotifier, List<Map<String, dynamic>>>(() {
      return RecentRoomsNotifier();
    });
