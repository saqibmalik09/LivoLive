import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LuckyRoomSvgaFlags {
  const LuckyRoomSvgaFlags({
    required this.fanbiEnabled,
    required this.multiplierEnabled,
  });

  final bool fanbiEnabled;
  final bool multiplierEnabled;

  static const defaults = LuckyRoomSvgaFlags(
    fanbiEnabled: true,
    multiplierEnabled: true,
  );
}

class LuckyRoomSvgaFlagsStore {
  LuckyRoomSvgaFlagsStore._();

  static const _ttl = Duration(seconds: 8);
  static LuckyRoomSvgaFlags _cached = LuckyRoomSvgaFlags.defaults;
  static DateTime? _fetchedAt;
  static Future<LuckyRoomSvgaFlags>? _inFlight;

  static bool _parseBool(String? raw, {required bool fallback}) {
    final v = raw?.trim().toLowerCase();
    if (v == null || v.isEmpty) return fallback;
    if (v == 'false' || v == '0' || v == 'off' || v == 'no') return false;
    if (v == 'true' || v == '1' || v == 'on' || v == 'yes') return true;
    return fallback;
  }

  static Future<LuckyRoomSvgaFlags> load({bool force = false}) async {
    final now = DateTime.now();
    final fresh =
        _fetchedAt != null && now.difference(_fetchedAt!) < _ttl && !force;
    if (fresh) return _cached;

    final existing = _inFlight;
    if (existing != null && !force) return existing;

    final future = _fetch();
    _inFlight = future;
    try {
      final flags = await future;
      _cached = flags;
      _fetchedAt = DateTime.now();
      return flags;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  static Future<LuckyRoomSvgaFlags> _fetch() async {
    try {
      final rows = await Supabase.instance.client
          .from('system_settings')
          .select('key, value')
          .inFilter('key', [
            'lucky_room_fanbi_svga_enabled',
            'lucky_room_multiplier_svga_enabled',
          ]);

      var fanbi = true;
      var multiplier = true;
      for (final row in rows) {
        final key = row['key']?.toString();
        final value = row['value']?.toString();
        if (key == 'lucky_room_fanbi_svga_enabled') {
          fanbi = _parseBool(value, fallback: true);
        } else if (key == 'lucky_room_multiplier_svga_enabled') {
          multiplier = _parseBool(value, fallback: true);
        }
      }
      return LuckyRoomSvgaFlags(
        fanbiEnabled: fanbi,
        multiplierEnabled: multiplier,
      );
    } catch (_) {
      return _cached;
    }
  }

  static void invalidate() {
    _fetchedAt = null;
  }
}

final luckyRoomSvgaFlagsProvider = FutureProvider<LuckyRoomSvgaFlags>((
  ref,
) async {
  return LuckyRoomSvgaFlagsStore.load(force: true);
});

final luckyRoomFanbiSvgaEnabledProvider = FutureProvider<bool>((ref) async {
  final flags = await ref.watch(luckyRoomSvgaFlagsProvider.future);
  return flags.fanbiEnabled;
});

final luckyRoomMultiplierSvgaEnabledProvider = FutureProvider<bool>((
  ref,
) async {
  final flags = await ref.watch(luckyRoomSvgaFlagsProvider.future);
  return flags.multiplierEnabled;
});
