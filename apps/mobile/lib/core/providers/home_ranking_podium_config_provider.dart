import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/services/home_ranking_podium_cache_service.dart';

enum RankingPodiumCategory { room, agency, charm, wealth }

class HomeRankingPodiumConfig {
  const HomeRankingPodiumConfig({
    required this.backgrounds,
    required this.slideIntervalMs,
    this.updatedAt,
  });

  final Map<RankingPodiumCategory, String> backgrounds;
  final int slideIntervalMs;
  final DateTime? updatedAt;

  String get cacheVersion =>
      updatedAt?.millisecondsSinceEpoch.toString() ?? 'default';

  String backgroundUrl(RankingPodiumCategory cat) =>
      backgrounds[cat]?.trim() ?? '';

  factory HomeRankingPodiumConfig.fromMap(Map<String, dynamic> map) {
    DateTime? updatedAt;
    final raw = map['updated_at'];
    if (raw is String && raw.isNotEmpty) {
      updatedAt = DateTime.tryParse(raw);
    }
    return HomeRankingPodiumConfig(
      backgrounds: {
        RankingPodiumCategory.room:
            (map['room_bg_url'] as String?)?.trim() ?? '',
        RankingPodiumCategory.agency:
            (map['agency_bg_url'] as String?)?.trim() ?? '',
        RankingPodiumCategory.charm:
            (map['charm_bg_url'] as String?)?.trim() ?? '',
        RankingPodiumCategory.wealth:
            (map['wealth_bg_url'] as String?)?.trim() ?? '',
      },
      slideIntervalMs: (map['slide_interval_ms'] as num?)?.toInt() ?? 5000,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'room_bg_url': backgrounds[RankingPodiumCategory.room] ?? '',
    'agency_bg_url': backgrounds[RankingPodiumCategory.agency] ?? '',
    'charm_bg_url': backgrounds[RankingPodiumCategory.charm] ?? '',
    'wealth_bg_url': backgrounds[RankingPodiumCategory.wealth] ?? '',
    'slide_interval_ms': slideIntervalMs,
    'updated_at': updatedAt?.toIso8601String(),
  };

  static HomeRankingPodiumConfig defaults() =>
      HomeRankingPodiumConfig.fromMap({});
}

class HomeRankingPodiumConfigNotifier
    extends AsyncNotifier<HomeRankingPodiumConfig> {
  @override
  Future<HomeRankingPodiumConfig> build() async {
    ref.keepAlive();
    final cached = await HomeRankingPodiumCacheService.loadCached();
    if (cached != null) {
      unawaited(_silentRefresh());
      return cached;
    }
    final remote = await _fetchRemote();
    await HomeRankingPodiumCacheService.saveCached(remote);
    return remote;
  }

  Future<void> _silentRefresh() async {
    try {
      final cached = await HomeRankingPodiumCacheService.loadCached();
      final remote = await _fetchRemote();
      if (!HomeRankingPodiumCacheService.hasChanged(cached, remote)) return;
      await HomeRankingPodiumCacheService.saveCached(remote);
      state = AsyncData(remote);
    } catch (e) {
      debugPrint('[RankingPodiumConfig] silent refresh failed: $e');
    }
  }

  Future<HomeRankingPodiumConfig> _fetchRemote() async {
    try {
      final response = await Supabase.instance.client
          .from('home_ranking_podium_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (response == null) return HomeRankingPodiumConfig.defaults();
      return HomeRankingPodiumConfig.fromMap(
        Map<String, dynamic>.from(response),
      );
    } catch (e) {
      debugPrint('[RankingPodiumConfig] fetch failed: $e');
      return await HomeRankingPodiumCacheService.loadCached() ??
          HomeRankingPodiumConfig.defaults();
    }
  }
}

final homeRankingPodiumConfigProvider =
    AsyncNotifierProvider<
      HomeRankingPodiumConfigNotifier,
      HomeRankingPodiumConfig
    >(HomeRankingPodiumConfigNotifier.new);
