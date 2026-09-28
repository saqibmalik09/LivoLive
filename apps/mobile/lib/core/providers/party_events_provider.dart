import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PartyEventKind {
  cpNative,
  weeklyStarNative,
  gameStarNative,
  skHostNative,
  webview,
}

PartyEventKind parseEventKind(String? raw, {String? legacyScreenTemplate}) {
  switch (raw?.toLowerCase()) {
    case 'cp_native':
      return PartyEventKind.cpNative;
    case 'weekly_star_native':
      return PartyEventKind.weeklyStarNative;
    case 'game_star_native':
      return PartyEventKind.gameStarNative;
    case 'sk_host_native':
      return PartyEventKind.skHostNative;
    case 'webview':
      return PartyEventKind.webview;
    default:
      break;
  }
  switch (legacyScreenTemplate?.toLowerCase()) {
    case 'cp_romance':
    case 'cp_event':
      return PartyEventKind.cpNative;
    case 'weekly_star':
      return PartyEventKind.weeklyStarNative;
    case 'game_star':
      return PartyEventKind.gameStarNative;
    case 'sk_host':
    case 'sk_party':
      return PartyEventKind.skHostNative;
    default:
      return PartyEventKind.webview;
  }
}

class PartyEvent {
  const PartyEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bannerUrl,
    required this.eventKind,
    required this.actionConfig,
    required this.isActive,
    required this.priority,
    this.startAt,
    this.endAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String bannerUrl;
  final PartyEventKind eventKind;
  final Map<String, dynamic> actionConfig;
  final bool isActive;
  final int priority;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? updatedAt;

  String get cacheVersion => updatedAt?.millisecondsSinceEpoch.toString() ?? id;

  String get versionedBannerUrl {
    if (bannerUrl.isEmpty) return bannerUrl;
    final uri = Uri.parse(bannerUrl);
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'v': cacheVersion})
        .toString();
  }

  bool get isExpired {
    if (endAt == null) return false;
    return DateTime.now().toUtc().isAfter(endAt!.toUtc());
  }

  bool get hasStarted {
    if (startAt == null) return true;
    return !DateTime.now().toUtc().isBefore(startAt!.toUtc());
  }

  factory PartyEvent.fromMap(Map<String, dynamic> map) {
    DateTime? parseTs(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
      return null;
    }

    return PartyEvent(
      id: map['id']?.toString() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      subtitle: (map['subtitle'] as String?)?.trim() ?? '',
      bannerUrl: (map['banner_url'] as String?)?.trim() ?? '',
      eventKind: parseEventKind(
        map['event_kind'] as String?,
        legacyScreenTemplate: map['screen_template'] as String?,
      ),
      actionConfig: map['action_config'] is Map
          ? Map<String, dynamic>.from(map['action_config'] as Map)
          : {},
      isActive: map['is_active'] as bool? ?? true,
      priority: (map['priority'] as num?)?.toInt() ?? 0,
      startAt: parseTs(map['start_at']),
      endAt: parseTs(map['end_at']),
      updatedAt: parseTs(map['updated_at']),
    );
  }
}

final partyEventsProvider = FutureProvider<List<PartyEvent>>((ref) async {
  ref.keepAlive();
  try {
    final response = await Supabase.instance.client
        .from('party_events')
        .select()
        .eq('is_active', true)
        .order('priority', ascending: false)
        .order('start_at', ascending: false);

    final now = DateTime.now().toUtc();
    return (response as List)
        .map((e) => PartyEvent.fromMap(Map<String, dynamic>.from(e)))
        .where((e) {
          if (!e.isActive) return false;
          if (e.bannerUrl.isEmpty &&
              e.eventKind != PartyEventKind.cpNative &&
              e.eventKind != PartyEventKind.weeklyStarNative &&
              e.eventKind != PartyEventKind.gameStarNative &&
              e.eventKind != PartyEventKind.skHostNative) {
            return false;
          }
          if (e.startAt != null && now.isBefore(e.startAt!.toUtc())) {
            return false;
          }
          return true;
        })
        .toList();
  } catch (e) {
    debugPrint('[partyEventsProvider] fetch failed: $e');
    return [];
  }
});

enum EventGiftMarkerKind { cp, weeklyStar, webview }

List<String> _giftIdsFromActionConfig(
  Map<String, dynamic> config, {
  required PartyEventKind kind,
}) {
  final ids = <String>{};

  void addId(dynamic raw) {
    final id = raw?.toString().trim() ?? '';
    if (id.isNotEmpty) ids.add(id);
  }

  if (kind == PartyEventKind.cpNative) {
    final raw = config['cp_gift_ids'];
    if (raw is List) {
      for (final e in raw) {
        addId(e);
      }
    }
    return ids.toList();
  }

  if (kind == PartyEventKind.weeklyStarNative ||
      kind == PartyEventKind.webview) {
    final gifts = config['weekly_star_gifts'];
    if (gifts is List && gifts.isNotEmpty) {
      for (final e in gifts) {
        if (e is Map) {
          addId(e['gift_id'] ?? e['giftId']);
        }
      }
    }
    if (ids.isEmpty) {
      final legacy = config['weekly_star_gift_ids'];
      if (legacy is List) {
        for (final e in legacy) {
          addId(e);
        }
      }
    }
    return ids.toList();
  }

  return const [];
}

final activeEventGiftMarkersProvider =
    Provider<Map<String, Set<EventGiftMarkerKind>>>((ref) {
      final eventsAsync = ref.watch(partyEventsProvider);
      final events = eventsAsync.valueOrNull ?? const <PartyEvent>[];
      final map = <String, Set<EventGiftMarkerKind>>{};

      for (final event in events) {
        if (!event.isActive || !event.hasStarted || event.isExpired) continue;

        final EventGiftMarkerKind? kind = switch (event.eventKind) {
          PartyEventKind.cpNative => EventGiftMarkerKind.cp,
          PartyEventKind.weeklyStarNative => EventGiftMarkerKind.weeklyStar,
          PartyEventKind.webview => EventGiftMarkerKind.webview,
          _ => null,
        };
        if (kind == null) continue;

        for (final giftId in _giftIdsFromActionConfig(
          event.actionConfig,
          kind: event.eventKind,
        )) {
          map.putIfAbsent(giftId, () => <EventGiftMarkerKind>{}).add(kind);
        }
      }

      return map;
    });

final hasActiveEventGiftMarkersProvider = Provider<bool>((ref) {
  return ref.watch(activeEventGiftMarkersProvider).isNotEmpty;
});

final activeEventGiftMarkerKindsProvider = Provider<Set<EventGiftMarkerKind>>((
  ref,
) {
  final kinds = <EventGiftMarkerKind>{};
  for (final set in ref.watch(activeEventGiftMarkersProvider).values) {
    kinds.addAll(set);
  }
  return kinds;
});
