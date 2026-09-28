import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/services/app_telemetry.dart';

class GiftRankingModel {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int score;
  final int rank;
  final int? userLevel;
  final int? charmLevel;
  final int? wealthLevel;
  final int? roomLevel;
  final String? rankFrame;
  final String? rankBadge;
  final String? agencyLevelBadgeUrl;

  GiftRankingModel({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.score,
    required this.rank,
    this.userLevel,
    this.charmLevel,
    this.wealthLevel,
    this.roomLevel,
    this.rankFrame,
    this.rankBadge,
    this.agencyLevelBadgeUrl,
  });

  factory GiftRankingModel.fromJson(Map<String, dynamic> json, String type) {
    String? badge;
    String? frame;

    if (json['ranking_assets'] != null) {
      Map<String, dynamic>? assetMap;
      if (json['ranking_assets'] is List &&
          (json['ranking_assets'] as List).isNotEmpty) {
        assetMap = Map<String, dynamic>.from(
          (json['ranking_assets'] as List).first as Map,
        );
      } else if (json['ranking_assets'] is Map) {
        assetMap = Map<String, dynamic>.from(json['ranking_assets'] as Map);
      }
      if (assetMap != null) {
        badge = assetMap['badge_url'] as String?;
        frame = assetMap['frame_url'] as String?;
      }
    }

    if (type == 'Room') {
      final roomData = json['rooms'] ?? {};
      final nestedStats = roomData['room_stats'];
      final roomStats = json['room_stats'] ?? nestedStats;
      final statsLevel = roomStats is Map
          ? (roomStats['current_level'] as num?)?.toInt()
          : null;
      return GiftRankingModel(
        userId: json['room_id'] ?? '',
        username: roomData['title'] ?? 'Room',
        avatarUrl: roomData['image_url'],
        score:
            (json['score'] as num?)?.toInt() ??
            (json['total_exp'] as num?)?.toInt() ??
            0,
        rank: json['rank'] ?? 0,
        roomLevel:
            statsLevel ??
            (json['current_level'] as num?)?.toInt() ??
            (roomData['room_level'] as num?)?.toInt() ??
            1,
        rankBadge: badge,
        rankFrame: frame,
      );
    }

    final userData = json['users'] ?? {};
    return GiftRankingModel(
      userId: json['user_id'] ?? '',
      username: userData['username'] ?? 'User',
      avatarUrl: userData['avatar_url'],
      score: json['score'] ?? 0,
      rank: json['rank'] ?? 0,
      userLevel: userData['user_level'] ?? 1,
      charmLevel: userData['charm_level'] ?? userData['user_level'] ?? 1,
      wealthLevel: userData['wealth_level'] ?? 1,
      rankBadge: badge,
      rankFrame: frame,
    );
  }
}

final rankingsProvider = FutureProvider.family<List<GiftRankingModel>, (String, String)>((
  ref,
  params,
) async {
  final type = params.$1;
  final period = params.$2;
  return AppTelemetry.traceAsync(
    'rankings_load',
    () async {
      final supabase = Supabase.instance.client;

      String table = 'gift_rankings';

      String dbPeriod = period.toLowerCase();
      if (dbPeriod == 'day') {
        dbPeriod = 'daily';
      } else if (dbPeriod == 'week') {
        dbPeriod = 'weekly';
      } else if (dbPeriod == 'month') {
        dbPeriod = 'monthly';
      }

      String select =
          '*, users:user_id(username, avatar_url, user_level, wealth_level)';
      if (type == 'Charm') {
        table = 'charm_rankings';
        select =
            '*, users:user_id(username, avatar_url, user_level, wealth_level, charm_level)';
      } else if (type == 'Room') {
        table = 'room_rankings';
        select =
            '*, rooms:room_id(title, image_url, host_id, room_stats(current_level))';
      } else {
        select =
            '*, users:user_id(username, avatar_url, user_level, wealth_level)';
      }

      try {
        if (type == 'Room') {
          const limit = 30;
          Future<List<Map<String, dynamic>>> fetchBoard(
            String rankingType,
          ) async {
            final res = await supabase
                .from('room_rankings')
                .select(select)
                .eq('ranking_type', rankingType)
                .order('rank', ascending: true)
                .limit(limit);
            return List<Map<String, dynamic>>.from(res as List);
          }

          var rows = await fetchBoard(dbPeriod);

          if (rows.length < 3) {
            final seen = <String>{
              for (final r in rows) (r['room_id']?.toString() ?? ''),
            }..remove('');
            for (final fallbackType in const ['weekly', 'monthly']) {
              if (fallbackType == dbPeriod) continue;
              if (rows.length >= limit) break;
              for (final row in await fetchBoard(fallbackType)) {
                final id = row['room_id']?.toString() ?? '';
                if (id.isEmpty || seen.contains(id)) continue;
                seen.add(id);
                rows.add(row);
                if (rows.length >= limit) break;
              }
            }
          }

          if (rows.length < 3) {
            final seen = <String>{
              for (final r in rows) (r['room_id']?.toString() ?? ''),
            }..remove('');
            final stats = await supabase
                .from('room_stats')
                .select(
                  '*, rooms:room_id(title, image_url, host_id), current_level',
                )
                .order('total_exp', ascending: false)
                .limit(limit);
            for (final row in List<Map<String, dynamic>>.from(stats as List)) {
              final id = row['room_id']?.toString() ?? '';
              if (id.isEmpty || seen.contains(id)) continue;
              seen.add(id);
              rows.add(row);
              if (rows.length >= limit) break;
            }
          }

          final assetResponse = await supabase
              .from('ranking_assets')
              .select('rank_position, frame_url, badge_url')
              .eq('ranking_type', dbPeriod)
              .eq('category', 'Room');

          final assets = List<Map<String, dynamic>>.from(assetResponse);

          return rows.asMap().entries.map((entry) {
            final index = entry.key;
            final json = Map<String, dynamic>.from(entry.value);
            final rank = index + 1;
            json['rank'] = rank;
            final asset = assets.firstWhere(
              (a) => a['rank_position'] == rank,
              orElse: () => {},
            );
            json['ranking_assets'] = asset;
            return GiftRankingModel.fromJson(json, type);
          }).toList();
        }

        final response = await supabase
            .from(table)
            .select(select)
            .eq('ranking_type', dbPeriod)
            .order('score', ascending: false)
            .limit(30);

        final assetResponse = await supabase
            .from('ranking_assets')
            .select('rank_position, frame_url, badge_url')
            .eq('ranking_type', dbPeriod)
            .eq('category', type);

        final assets = List<Map<String, dynamic>>.from(assetResponse);

        return (response as List).asMap().entries.map((entry) {
          final json = Map<String, dynamic>.from(entry.value);
          final rank = (json['rank'] as num?)?.toInt() ?? (entry.key + 1);
          json['rank'] = rank;
          final asset = assets.firstWhere(
            (a) => a['rank_position'] == rank,
            orElse: () => {},
          );
          json['ranking_assets'] = asset;
          return GiftRankingModel.fromJson(json, type);
        }).toList();
      } catch (e, st) {
        await AppTelemetry.recordError(
          e,
          st,
          reason: 'rankingsProvider',
          keys: {'type': type, 'period': period},
        );
        debugPrint('DEBUG ERROR fetching $type rankings: $e');
        return [];
      }
    },
    keys: {'type': type, 'period': period},
    slowMs: 4000,
  );
});

final giftRankingsProvider =
    FutureProvider.family<List<GiftRankingModel>, String>((ref, period) {
      return ref.watch(rankingsProvider(('Gift', period)).future);
    });

final giftsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  try {
    final resGifts = await supabase
        .from('gifts')
        .select()
        .order('price_coins', ascending: true);

    if ((resGifts as List).isNotEmpty) {
      return List<Map<String, dynamic>>.from(resGifts);
    }

    final resShop = await supabase
        .from('shop_items')
        .select('*, shop_categories(name)')
        .eq('is_gift', true)
        .eq('is_active', true)
        .order('price_coins', ascending: true);

    return (resShop as List)
        .map(
          (item) => {
            'id': item['id'],
            'name': item['name'],
            'price_coins': item['price_coins'],
            'icon_url': item['image_url'] ?? item['svga_url'],
            'animation_url': item['svga_url'],
          },
        )
        .toList();
  } catch (e) {
    debugPrint('Error fetching gifts: $e');
    return [];
  }
});
