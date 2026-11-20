import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';

class AgencyMemberPreview {
  const AgencyMemberPreview({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.countryCode,
    this.wealthLevel = 1,
    this.charmLevel = 1,
  });

  final String userId;
  final String username;
  final String? avatarUrl;
  final String? countryCode;
  final int wealthLevel;
  final int charmLevel;
}

class AgencyRoomPreview {
  const AgencyRoomPreview({
    required this.roomId,
    required this.title,
    this.imageUrl,
    required this.hostUsername,
    this.hostAvatarUrl,
    this.hostCountryCode,
    this.roomLabel = '',
    this.onlineCount = 0,
  });

  final String roomId;
  final String title;
  final String? imageUrl;
  final String hostUsername;
  final String? hostAvatarUrl;
  final String? hostCountryCode;
  final String roomLabel;
  final int onlineCount;
}

class AgencyProfileModel {
  const AgencyProfileModel({
    required this.id,
    required this.name,
    required this.agencyCode,
    required this.memberCount,
    required this.totalExp,
    required this.level,
    required this.tierName,
    required this.owner,
    required this.expForCurrentLevel,
    required this.expForNextLevel,
    this.announcement,
    this.honorStar,
    this.charmStar,
    this.rooms = const [],
    this.heroFrameUrl,
    this.honorFrameUrl,
    this.charmFrameUrl,
    this.levelBadgeUrl,
  });

  final String id;
  final String name;
  final String agencyCode;
  final int memberCount;
  final int totalExp;
  final int level;
  final String tierName;
  final AgencyMemberPreview owner;
  final int expForCurrentLevel;
  final int expForNextLevel;
  final String? announcement;
  final AgencyMemberPreview? honorStar;
  final AgencyMemberPreview? charmStar;
  final List<AgencyRoomPreview> rooms;
  final String? heroFrameUrl;
  final String? honorFrameUrl;
  final String? charmFrameUrl;
  final String? levelBadgeUrl;

  int get nextLevel => level + 1;

  double get levelProgress {
    final start = expForCurrentLevel;
    final end = expForNextLevel;
    if (end <= start) return 1;
    return ((totalExp - start) / (end - start)).clamp(0.0, 1.0);
  }
}

AgencyMemberPreview _memberFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return const AgencyMemberPreview(userId: '', username: 'User');
  }
  return AgencyMemberPreview(
    userId: json['id']?.toString() ?? '',
    username: json['username'] as String? ?? 'User',
    avatarUrl: json['avatar_url'] as String?,
    countryCode: json['country_code'] as String?,
    wealthLevel: (json['wealth_level'] as num?)?.toInt() ?? 1,
    charmLevel: (json['charm_level'] as num?)?.toInt() ?? 1,
  );
}

final agencyProfileProvider = FutureProvider.family<AgencyProfileModel?, String>((
  ref,
  agencyId,
) async {
  if (agencyId.isEmpty) return null;

  try {
    final supabase = Supabase.instance.client;

    final agency = await supabase
        .from('agencies')
        .select(
          'id, name, agency_code, owner_id, users!owner_id(id, username, avatar_url, country_code, bio, wealth_level, charm_level, user_level)',
        )
        .eq('id', agencyId)
        .maybeSingle();

    if (agency == null) return null;

    final ownerJson = agency['users'] as Map<String, dynamic>?;
    final ownerId = agency['owner_id']?.toString() ?? '';

    final membersResponse = await supabase
        .from('agency_members')
        .select(
          'user_id, users:user_id(id, username, avatar_url, country_code, wealth_level, charm_level, user_level, charm_value, wealth_value)',
        )
        .eq('agency_id', agencyId);

    final members = (membersResponse as List)
        .map((e) => Map<String, dynamic>.from(e['users'] as Map? ?? {}))
        .where((u) => u['id'] != null)
        .toList();

    if (ownerJson != null &&
        !members.any((m) => m['id']?.toString() == ownerId)) {
      members.add(ownerJson);
    }

    AgencyMemberPreview? honorStar;
    AgencyMemberPreview? charmStar;
    if (members.isNotEmpty) {
      members.sort(
        (a, b) => ((b['wealth_value'] as num?)?.toInt() ?? 0).compareTo(
          (a['wealth_value'] as num?)?.toInt() ?? 0,
        ),
      );
      honorStar = _memberFromJson(members.first);

      final byCharm = List<Map<String, dynamic>>.from(members)
        ..sort(
          (a, b) => ((b['charm_value'] as num?)?.toInt() ?? 0).compareTo(
            (a['charm_value'] as num?)?.toInt() ?? 0,
          ),
        );
      charmStar = _memberFromJson(byCharm.first);
    }

    final memberIds = members
        .map((m) => m['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    if (ownerId.isNotEmpty && !memberIds.contains(ownerId)) {
      memberIds.add(ownerId);
    }

    var rooms = <AgencyRoomPreview>[];
    if (memberIds.isNotEmpty) {
      final roomsResponse = await supabase
          .from('rooms')
          .select(
            'id, short_id, title, image_url, online_users_count, host_id, users:host_id(username, avatar_url, country_code)',
          )
          .inFilter('host_id', memberIds)
          .eq('is_active', true)
          .order('online_users_count', ascending: false)
          .limit(20);

      rooms = (roomsResponse as List).map((raw) {
        final json = Map<String, dynamic>.from(raw);
        final host = json['users'] as Map<String, dynamic>? ?? {};
        final roomId = json['id']?.toString() ?? '';
        final publicId = json['short_id']?.toString();
        return AgencyRoomPreview(
          roomId: roomId,
          title: json['title'] as String? ?? 'Room',
          imageUrl: json['image_url'] as String?,
          hostUsername: host['username'] as String? ?? 'Host',
          hostAvatarUrl: host['avatar_url'] as String?,
          hostCountryCode: host['country_code'] as String?,
          roomLabel: (publicId != null && publicId.isNotEmpty)
              ? publicId
              : (roomId.length >= 8 ? roomId.substring(0, 8) : roomId),
          onlineCount: (json['online_users_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    }

    var totalExp = 0;
    if (ownerId.isNotEmpty) {
      // Summed server-side. Selecting every earning_logs row for the owner and
      // adding them up here meant a full scan of a 2.4M-row table — 225k rows
      // for the larger agencies — which hit the statement timeout and failed
      // the whole provider, so the agency page never rendered.
      final total = await supabase.rpc(
        'agency_total_exp',
        params: <String, dynamic>{'p_owner_id': ownerId},
      );
      totalExp = (total as num?)?.toInt() ?? 0;
    }

    final ranking = await supabase
        .from('agency_rankings')
        .select('score')
        .eq('agency_id', agencyId)
        .eq('ranking_type', 'weekly')
        .maybeSingle();
    final rankScore = (ranking?['score'] as num?)?.toInt() ?? 0;
    if (rankScore > totalExp) totalExp = rankScore;

    final levelConfigs = await ref.read(agencyLevelConfigsProvider.future);
    final level = agencyLevelFromExp(levelConfigs, totalExp);
    final tierName = agencyTierName(levelConfigs, level);
    final currentExpThreshold = agencyExpThreshold(levelConfigs, level);
    final nextExpThreshold = agencyExpThreshold(levelConfigs, level + 1);
    final levelConfig = agencyConfigForLevel(levelConfigs, level);
    final announcement = ownerJson?['bio'] as String?;

    return AgencyProfileModel(
      id: agency['id']?.toString() ?? agencyId,
      name: agency['name'] as String? ?? 'Agency',
      agencyCode: agency['agency_code']?.toString() ?? '',
      memberCount: (membersResponse as List).length,
      totalExp: totalExp,
      level: level,
      tierName: tierName,
      expForCurrentLevel: currentExpThreshold,
      expForNextLevel: nextExpThreshold > currentExpThreshold
          ? nextExpThreshold
          : currentExpThreshold + 2500000000,
      owner: _memberFromJson(ownerJson),
      announcement: (announcement?.trim().isNotEmpty ?? false)
          ? announcement!.trim()
          : '${agency['name']} welcomes you!',
      honorStar: honorStar,
      charmStar: charmStar,
      rooms: rooms,
      heroFrameUrl: levelConfig == null
          ? null
          : agencyHeroFrameUrl(levelConfig),
      honorFrameUrl: levelConfig == null
          ? null
          : agencyHonorFrameUrl(levelConfig),
      charmFrameUrl: levelConfig == null
          ? null
          : agencyCharmFrameUrl(levelConfig),
      levelBadgeUrl: levelConfig == null ? null : agencyBadgeUrl(levelConfig),
    );
  } catch (e, st) {
    debugPrint('[AgencyProfile] fetch failed: $e\n$st');
    return null;
  }
});
