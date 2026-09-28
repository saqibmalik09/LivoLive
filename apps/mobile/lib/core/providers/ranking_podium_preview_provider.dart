import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/agency_ranking_provider.dart';
import 'package:sk_live/core/providers/gift_provider.dart';
import 'package:sk_live/core/providers/home_ranking_podium_config_provider.dart';

class RankingPodiumEntry {
  const RankingPodiumEntry({
    required this.id,
    required this.title,
    this.avatarUrl,
    this.frameUrl,
    this.badgeUrl,
    required this.rank,
  });

  final String id;
  final String title;
  final String? avatarUrl;
  final String? frameUrl;
  final String? badgeUrl;
  final int rank;

  static RankingPodiumEntry fromGift(GiftRankingModel m) => RankingPodiumEntry(
    id: m.userId,
    title: m.username,
    avatarUrl: m.avatarUrl,
    frameUrl: m.rankFrame,
    badgeUrl: m.rankBadge,
    rank: m.rank,
  );

  static RankingPodiumEntry fromAgency(AgencyRankingModel m) =>
      RankingPodiumEntry(
        id: m.agencyId,
        title: m.name,
        avatarUrl: m.avatarUrl,
        frameUrl: m.rankFrame,
        badgeUrl: m.rankBadge,
        rank: m.rank,
      );
}

class RankingPodiumSlideData {
  const RankingPodiumSlideData({required this.category, required this.top3});

  final RankingPodiumCategory category;
  final List<RankingPodiumEntry> top3;
}

final rankingPodiumSlidesProvider =
    FutureProvider<List<RankingPodiumSlideData>>((ref) async {
      const period = 'Day';

      final room = await ref.watch(rankingsProvider(('Room', period)).future);
      final agency = await ref.watch(agencyRankingsProvider(period).future);
      final charm = await ref.watch(rankingsProvider(('Charm', period)).future);
      final wealth = await ref.watch(rankingsProvider(('Gift', period)).future);

      List<RankingPodiumEntry> top3FromGift(List<GiftRankingModel> list) =>
          list.take(3).map(RankingPodiumEntry.fromGift).toList();

      List<RankingPodiumEntry> top3FromAgency(List<AgencyRankingModel> list) =>
          list.take(3).map(RankingPodiumEntry.fromAgency).toList();

      return [
        RankingPodiumSlideData(
          category: RankingPodiumCategory.room,
          top3: top3FromGift(room),
        ),
        RankingPodiumSlideData(
          category: RankingPodiumCategory.agency,
          top3: top3FromAgency(agency),
        ),
        RankingPodiumSlideData(
          category: RankingPodiumCategory.charm,
          top3: top3FromGift(charm),
        ),
        RankingPodiumSlideData(
          category: RankingPodiumCategory.wealth,
          top3: top3FromGift(wealth),
        ),
      ];
    });
