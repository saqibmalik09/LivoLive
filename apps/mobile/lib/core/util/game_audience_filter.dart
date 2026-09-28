import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<List<Map<String, dynamic>>> filterGamesByAudience(
  List<Map<String, dynamic>> games,
) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null || uid.isEmpty || games.isEmpty) return games;

  try {
    final response = await Supabase.instance.client
        .from('room_game_visibility')
        .select('scope, target_id, mode, user_id');
    final rows = List<Map<String, dynamic>>.from(response as List);
    if (rows.isEmpty) return games;

    final rules = <String, ({String mode, Set<String> users})>{};
    for (final row in rows) {
      final scope = row['scope']?.toString() ?? '';
      final target = row['target_id']?.toString() ?? '';
      final mode = row['mode']?.toString() ?? '';
      final userId = row['user_id']?.toString() ?? '';
      if (scope.isEmpty || target.isEmpty || userId.isEmpty) continue;
      if (mode != 'hide_from' && mode != 'show_only') continue;
      final key = '$scope::$target';
      final existing = rules[key];
      if (existing == null) {
        rules[key] = (mode: mode, users: {userId});
      } else {
        existing.users.add(userId);
        if (mode == 'show_only' || existing.mode == 'show_only') {
          rules[key] = (mode: 'show_only', users: existing.users);
        }
      }
    }
    if (rules.isEmpty) return games;

    bool allowed(String scope, String? targetId) {
      if (targetId == null || targetId.isEmpty) return true;
      final rule = rules['$scope::$targetId'];
      if (rule == null) return true;
      if (rule.mode == 'show_only') return rule.users.contains(uid);
      return !rule.users.contains(uid);
    }

    return games.where((g) {
      final id = g['id']?.toString();
      if (!allowed('game_config', id)) return false;

      final cfg = g['config_data'];
      final isTulasi = cfg is Map && cfg['provider']?.toString() == 'tulasi';
      if (isTulasi) {
        final tulasiId =
            cfg['tulasi_game_id']?.toString() ?? cfg['platform_id']?.toString();
        if (!allowed('tulasi_game', tulasiId)) return false;
      }
      return true;
    }).toList();
  } catch (e) {
    debugPrint('[game_audience] filter failed: $e');
    return games;
  }
}

Future<List<T>> filterAudienceItems<T>({
  required List<T> items,
  required String Function(T) idOf,
  required Map<String, dynamic>? Function(T) configDataOf,
}) async {
  final asMaps = items
      .map(
        (item) => <String, dynamic>{
          'id': idOf(item),
          if (configDataOf(item) != null) 'config_data': configDataOf(item),
        },
      )
      .toList();
  final visible = await filterGamesByAudience(asMaps);
  final allowedIds = visible.map((g) => g['id']?.toString() ?? '').toSet();
  return items.where((item) => allowedIds.contains(idOf(item))).toList();
}
