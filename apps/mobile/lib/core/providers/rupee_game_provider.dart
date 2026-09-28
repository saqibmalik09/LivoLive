import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RupeeGameCampaign {
  const RupeeGameCampaign({
    required this.id,
    required this.title,
    required this.subtitle,
    this.heroImageUrl,
    required this.entryPriceCoins,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.maxEntriesPerUser,
    required this.drawMode,
    required this.refundNonWinners,
    required this.announcementHours,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? heroImageUrl;
  final int entryPriceCoins;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final int maxEntriesPerUser;
  final String drawMode;
  final bool refundNonWinners;
  final int announcementHours;

  factory RupeeGameCampaign.fromJson(Map<String, dynamic> json) {
    return RupeeGameCampaign(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Rupee Game',
      subtitle: json['subtitle'] as String? ?? '',
      heroImageUrl: json['hero_image_url'] as String?,
      entryPriceCoins: (json['entry_price_coins'] as num?)?.toInt() ?? 1,
      startsAt:
          DateTime.tryParse(json['starts_at']?.toString() ?? '') ??
          DateTime.now(),
      endsAt:
          DateTime.tryParse(json['ends_at']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'draft',
      maxEntriesPerUser: (json['max_entries_per_user'] as num?)?.toInt() ?? 1,
      drawMode: json['draw_mode'] as String? ?? 'manual',
      refundNonWinners: json['refund_non_winners'] as bool? ?? true,
      announcementHours: (json['announcement_hours'] as num?)?.toInt() ?? 48,
    );
  }
}

class RupeeGamePrize {
  const RupeeGamePrize({
    required this.id,
    required this.campaignId,
    required this.name,
    this.imageUrl,
    required this.originalValueLabel,
    required this.participantCount,
    required this.drawStatus,
    this.winnerUserId,
    this.comingSoon = false,
  });

  final String id;
  final String campaignId;
  final String name;
  final String? imageUrl;
  final String originalValueLabel;
  final int participantCount;
  final String drawStatus;
  final String? winnerUserId;
  final bool comingSoon;

  bool get isDrawn => drawStatus != 'pending';

  factory RupeeGamePrize.fromJson(Map<String, dynamic> json) {
    return RupeeGamePrize(
      id: json['id']?.toString() ?? '',
      campaignId: json['campaign_id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Prize',
      imageUrl: json['image_url'] as String?,
      originalValueLabel: json['original_value_label'] as String? ?? '',
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      drawStatus: json['draw_status'] as String? ?? 'pending',
      winnerUserId: json['winner_user_id']?.toString(),
      comingSoon: json['coming_soon'] as bool? ?? false,
    );
  }
}

class RupeeGameHelpSection {
  const RupeeGameHelpSection({
    required this.id,
    required this.sectionKey,
    required this.title,
    required this.items,
    required this.isExpandedDefault,
  });

  final String id;
  final String sectionKey;
  final String title;
  final List<String> items;
  final bool isExpandedDefault;

  factory RupeeGameHelpSection.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    List<String> items = [];
    if (content is Map && content['items'] is List) {
      items = (content['items'] as List).map((e) => e.toString()).toList();
    }
    return RupeeGameHelpSection(
      id: json['id']?.toString() ?? '',
      sectionKey: json['section_key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      items: items,
      isExpandedDefault: json['is_expanded_default'] as bool? ?? false,
    );
  }
}

final activeRupeeGameCampaignsProvider =
    FutureProvider<List<RupeeGameCampaign>>((ref) async {
      try {
        final now = DateTime.now().toUtc().toIso8601String();
        final response = await Supabase.instance.client
            .from('rupee_game_campaigns')
            .select()
            .eq('is_active', true)
            .eq('status', 'active')
            .lte('starts_at', now)
            .gte('ends_at', now)
            .order('sort_order', ascending: true);

        return (response as List)
            .map(
              (e) => RupeeGameCampaign.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      } catch (e, st) {
        debugPrint('[RupeeGame] campaigns fetch failed: $e\n$st');
        return [];
      }
    });

final rupeeGamePrizesProvider =
    FutureProvider.family<List<RupeeGamePrize>, String>((
      ref,
      campaignId,
    ) async {
      if (campaignId.isEmpty) return [];
      try {
        final response = await Supabase.instance.client
            .from('rupee_game_prizes')
            .select()
            .eq('campaign_id', campaignId)
            .order('sort_order', ascending: true);

        return (response as List)
            .map((e) => RupeeGamePrize.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('[RupeeGame] prizes fetch failed: $e');
        return [];
      }
    });

final myRupeeGameEntriesProvider = FutureProvider<Set<String>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return {};

  try {
    final response = await Supabase.instance.client
        .from('rupee_game_entries')
        .select('prize_id')
        .eq('user_id', userId);

    return (response as List)
        .map((e) => e['prize_id']?.toString())
        .whereType<String>()
        .toSet();
  } catch (e) {
    debugPrint('[RupeeGame] entries fetch failed: $e');
    return {};
  }
});

final rupeeGameHelpProvider = FutureProvider<List<RupeeGameHelpSection>>((
  ref,
) async {
  try {
    final response = await Supabase.instance.client
        .from('rupee_game_help_sections')
        .select()
        .order('sort_order', ascending: true);

    return (response as List)
        .map((e) => RupeeGameHelpSection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (e) {
    debugPrint('[RupeeGame] help fetch failed: $e');
    return [];
  }
});

Future<Map<String, dynamic>> enterRupeeGame(String prizeId) async {
  final response = await Supabase.instance.client.rpc(
    'enter_rupee_game',
    params: {'p_prize_id': prizeId},
  );
  if (response is Map) {
    return Map<String, dynamic>.from(response);
  }
  return {'success': false, 'message': 'Unexpected response'};
}
