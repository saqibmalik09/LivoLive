import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/home_ranking_podium_config_provider.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PodiumRankFrame {
  const PodiumRankFrame({required this.url, this.isSvga = false});

  final String url;
  final bool isSvga;

  bool get isEmpty => url.trim().isEmpty;

  Map<String, dynamic> toJson() => {'url': url, 'isSvga': isSvga};

  factory PodiumRankFrame.fromJson(Map<String, dynamic> json) {
    return PodiumRankFrame(
      url: json['url']?.toString() ?? '',
      isSvga: json['isSvga'] == true,
    );
  }
}

class HomePodiumFramesBundle {
  const HomePodiumFramesBundle({
    this.shared = const {},
    this.bySlide = const {},
  });

  final Map<int, PodiumRankFrame> shared;
  final Map<RankingPodiumCategory, Map<int, PodiumRankFrame>> bySlide;

  Map<int, PodiumRankFrame> forSlide(RankingPodiumCategory category) {
    final specific = bySlide[category] ?? const {};
    final out = <int, PodiumRankFrame>{};
    for (final rank in const [1, 2, 3]) {
      final frame = specific[rank] ?? shared[rank];
      if (frame != null && !frame.isEmpty) {
        out[rank] = frame;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'shared': shared.map((k, v) => MapEntry(k.toString(), v.toJson())),
    'bySlide': bySlide.map(
      (cat, frames) => MapEntry(
        cat.name,
        frames.map((k, v) => MapEntry(k.toString(), v.toJson())),
      ),
    ),
  };

  factory HomePodiumFramesBundle.fromJson(Map<String, dynamic> json) {
    Map<int, PodiumRankFrame> parseFrames(dynamic raw) {
      if (raw is! Map) return {};
      final out = <int, PodiumRankFrame>{};
      for (final e in raw.entries) {
        final pos = int.tryParse(e.key.toString());
        if (pos == null || e.value is! Map) continue;
        final frame = PodiumRankFrame.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
        if (!frame.isEmpty) out[pos] = frame;
      }
      return out;
    }

    final shared = parseFrames(json['shared']);
    final bySlide = <RankingPodiumCategory, Map<int, PodiumRankFrame>>{};
    final rawSlides = json['bySlide'];
    if (rawSlides is Map) {
      for (final e in rawSlides.entries) {
        RankingPodiumCategory? cat;
        for (final c in RankingPodiumCategory.values) {
          if (c.name == e.key.toString()) {
            cat = c;
            break;
          }
        }
        if (cat == null) continue;
        final frames = parseFrames(e.value);
        if (frames.isNotEmpty) bySlide[cat] = frames;
      }
    }
    return HomePodiumFramesBundle(shared: shared, bySlide: bySlide);
  }
}

String _dbCategoryForSlide(RankingPodiumCategory cat) => switch (cat) {
  RankingPodiumCategory.room => 'PodiumRoom',
  RankingPodiumCategory.agency => 'PodiumAgency',
  RankingPodiumCategory.charm => 'PodiumCharm',
  RankingPodiumCategory.wealth => 'PodiumWealth',
};

RankingPodiumCategory? _slideFromDbCategory(String category) =>
    switch (category) {
      'PodiumRoom' => RankingPodiumCategory.room,
      'PodiumAgency' => RankingPodiumCategory.agency,
      'PodiumCharm' => RankingPodiumCategory.charm,
      'PodiumWealth' => RankingPodiumCategory.wealth,
      _ => null,
    };

Map<int, PodiumRankFrame> _parseFrameRows(List<dynamic> rows) {
  final map = <int, PodiumRankFrame>{};
  for (final row in rows) {
    final pos = (row['rank_position'] as num?)?.toInt();
    final url = (row['frame_url'] as String?)?.trim() ?? '';
    if (pos == null || url.isEmpty) continue;
    final mediaType = row['frame_media_type']?.toString().toLowerCase();
    final isSvga = mediaType == 'svga' || MediaUrlUtil.isSvgaUrl(url);
    map[pos] = PodiumRankFrame(url: url, isSvga: isSvga);
  }
  return map;
}

Future<HomePodiumFramesBundle> _fetchHomePodiumFramesRemote() async {
  const dbPeriod = 'daily';
  const categories = <String>[
    'Podium',
    'PodiumRoom',
    'PodiumAgency',
    'PodiumCharm',
    'PodiumWealth',
  ];

  try {
    final response = await Supabase.instance.client
        .from('ranking_assets')
        .select('category, rank_position, frame_url, frame_media_type')
        .eq('ranking_type', dbPeriod)
        .inFilter('category', categories);

    final shared = <int, PodiumRankFrame>{};
    final bySlide = <RankingPodiumCategory, Map<int, PodiumRankFrame>>{};

    for (final row in response as List) {
      final category = row['category']?.toString() ?? '';
      final pos = (row['rank_position'] as num?)?.toInt();
      final url = (row['frame_url'] as String?)?.trim() ?? '';
      if (pos == null || url.isEmpty) continue;

      final mediaType = row['frame_media_type']?.toString().toLowerCase();
      final frame = PodiumRankFrame(
        url: url,
        isSvga: mediaType == 'svga' || MediaUrlUtil.isSvgaUrl(url),
      );

      if (category == 'Podium') {
        shared[pos] = frame;
        continue;
      }
      final slide = _slideFromDbCategory(category);
      if (slide == null) continue;
      bySlide.putIfAbsent(slide, () => <int, PodiumRankFrame>{});
      bySlide[slide]![pos] = frame;
    }

    return HomePodiumFramesBundle(shared: shared, bySlide: bySlide);
  } catch (_) {
    try {
      final sharedRows = await Supabase.instance.client
          .from('ranking_assets')
          .select('rank_position, frame_url')
          .eq('category', 'Podium')
          .eq('ranking_type', dbPeriod);
      final shared = _parseFrameRows(sharedRows as List);

      final bySlide = <RankingPodiumCategory, Map<int, PodiumRankFrame>>{};
      for (final cat in RankingPodiumCategory.values) {
        final rows = await Supabase.instance.client
            .from('ranking_assets')
            .select('rank_position, frame_url')
            .eq('category', _dbCategoryForSlide(cat))
            .eq('ranking_type', dbPeriod);
        final map = _parseFrameRows(rows as List);
        if (map.isNotEmpty) bySlide[cat] = map;
      }

      return HomePodiumFramesBundle(shared: shared, bySlide: bySlide);
    } catch (_) {
      return const HomePodiumFramesBundle();
    }
  }
}

final homePodiumFramesProvider = FutureProvider<HomePodiumFramesBundle>((
  ref,
) async {
  ref.keepAlive();

  final cachedRaw = await HiveCacheService.loadRankFrames();
  HomePodiumFramesBundle? cached;
  if (cachedRaw != null && cachedRaw.isNotEmpty) {
    try {
      cached = HomePodiumFramesBundle.fromJson(cachedRaw);
    } catch (e) {
      debugPrint('[homePodiumFrames] decode cache failed: $e');
    }
  }

  if (cached != null && cached.shared.isNotEmpty) {
    Future(() async {
      try {
        final remote = await _fetchHomePodiumFramesRemote();
        await HiveCacheService.saveRankFrames(remote.toJson());
      } catch (e) {
        debugPrint('[homePodiumFrames] bg refresh failed: $e');
      }
    });
    return cached;
  }

  final remote = await _fetchHomePodiumFramesRemote();
  await HiveCacheService.saveRankFrames(remote.toJson());
  return remote;
});

final podiumRankFramesProvider =
    FutureProvider.family<Map<int, PodiumRankFrame>, String>((
      ref,
      period,
    ) async {
      final bundle = await ref.watch(homePodiumFramesProvider.future);
      return bundle.shared;
    });
