import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/provider_cache.dart';

enum BuddyTier {
  friend,
  bestie,
  homie;

  String get dbValue => name;

  String get label {
    switch (this) {
      case BuddyTier.friend:
        return 'Friend';
      case BuddyTier.bestie:
        return 'Bestie';
      case BuddyTier.homie:
        return 'Homie';
    }
  }

  String get inviteSubtitle {
    switch (this) {
      case BuddyTier.friend:
        return 'Invite friends to become your Friend!';
      case BuddyTier.bestie:
        return 'Invite friends to become your bestie!';
      case BuddyTier.homie:
        return 'Invite friends to become your bro!';
    }
  }

  String get inviteRuleText {
    switch (this) {
      case BuddyTier.friend:
        return 'You can invite friends with over 300K intimacy and mutual follows to become Friend';
      case BuddyTier.bestie:
        return 'You can invite friends with over 2M intimacy and mutual follows to become Bestie';
      case BuddyTier.homie:
        return 'You can invite friends with over 5M intimacy and mutual follows to become Homie';
    }
  }

  /// Icon for the tier, shown on the Buddies tabs.
  ///
  /// The three tiers were named in plain text with nothing to tell them apart
  /// at a glance. Each now carries its own mark and colour.
  IconData get icon {
    switch (this) {
      case BuddyTier.friend:
        return Icons.person_rounded;
      case BuddyTier.bestie:
        return Icons.favorite_rounded;
      case BuddyTier.homie:
        return Icons.local_fire_department_rounded;
    }
  }

  /// Two-stop gradient for the tier's icon badge, light stop first.
  List<Color> get colors {
    switch (this) {
      case BuddyTier.friend:
        return const [Color(0xFF7EC4FF), Color(0xFF2574D6)];
      case BuddyTier.bestie:
        return const [Color(0xFFFF8FA8), Color(0xFFD62246)];
      case BuddyTier.homie:
        return const [Color(0xFFFFC46E), Color(0xFFE07A00)];
    }
  }

  String get bgAsset {
    switch (this) {
      case BuddyTier.friend:
        return 'assets/social/buddies/friend_bg.webp';
      case BuddyTier.bestie:
        return 'assets/social/buddies/bestie.webp';
      case BuddyTier.homie:
        return 'assets/social/buddies/homie_bg.webp';
    }
  }

  int get threshold {
    switch (this) {
      case BuddyTier.friend:
        return 300000;
      case BuddyTier.bestie:
        return 2000000;
      case BuddyTier.homie:
        return 5000000;
    }
  }

  static BuddyTier? tryParse(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'friend':
        return BuddyTier.friend;
      case 'bestie':
        return BuddyTier.bestie;
      case 'homie':
        return BuddyTier.homie;
      default:
        return null;
    }
  }
}

@immutable
class IntimacyBoard {
  const IntimacyBoard({
    required this.couple,
    required this.buddies,
    required this.closeFriendsCount,
    required this.closeFriendsLimit,
  });

  final Map<String, dynamic>? couple;
  final List<Map<String, dynamic>> buddies;
  final int closeFriendsCount;
  final int closeFriendsLimit;

  factory IntimacyBoard.fromJson(Map<String, dynamic> json) {
    final buddiesRaw = json['buddies'];
    return IntimacyBoard(
      couple: json['couple'] is Map
          ? Map<String, dynamic>.from(json['couple'] as Map)
          : null,
      buddies: buddiesRaw is List
          ? buddiesRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [],
      closeFriendsCount: (json['close_friends_count'] as num?)?.toInt() ?? 0,
      closeFriendsLimit: (json['close_friends_limit'] as num?)?.toInt() ?? 6,
    );
  }

  List<Map<String, dynamic>> get allCards {
    final list = <Map<String, dynamic>>[];
    if (couple != null) list.add(couple!);
    list.addAll(buddies);
    return list;
  }
}

final intimacyBoardProvider = FutureProvider.autoDispose
    .family<IntimacyBoard, String>((ref, userId) async {
      cacheFamilyEntry(ref);
      final res = await Supabase.instance.client.rpc(
        'list_user_intimacy_board',
        params: {'p_user_id': userId},
      );
      debugPrint(
        '[IntimacyBoard] user=$userId rawType=${res.runtimeType} raw=$res',
      );
      Map<String, dynamic>? map;
      if (res is Map) {
        map = Map<String, dynamic>.from(res);
      } else if (res is String) {}
      if (map != null) {
        return IntimacyBoard.fromJson(map);
      }
      return const IntimacyBoard(
        couple: null,
        buddies: [],
        closeFriendsCount: 0,
        closeFriendsLimit: 6,
      );
    });

final buddyEligibleProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      tier,
    ) async {
      final res = await Supabase.instance.client.rpc(
        'list_buddy_eligible',
        params: {'p_tier': tier},
      );
      if (res is! List) return const [];
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });

class BuddyActions {
  static Future<Map<String, dynamic>> invite({
    required String inviteeId,
    required BuddyTier tier,
  }) async {
    final res = await Supabase.instance.client.rpc(
      'invite_buddy',
      params: {'p_invitee_id': inviteeId, 'p_tier': tier.dbValue},
    );
    return res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{'success': false, 'message': 'Invite failed'};
  }

  static Future<Map<String, dynamic>> respond({
    required String invitationId,
    required bool accept,
  }) async {
    final res = await Supabase.instance.client.rpc(
      'respond_buddy_invite',
      params: {'p_invitation_id': invitationId, 'p_accept': accept},
    );
    return res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{'success': false, 'message': 'Respond failed'};
  }

  static Future<Map<String, dynamic>> remove(String otherUserId) async {
    final res = await Supabase.instance.client.rpc(
      'remove_buddy',
      params: {'p_other_user_id': otherUserId},
    );
    return res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{'success': false, 'message': 'Remove failed'};
  }

  static Future<Map<String, dynamic>?> fetchPendingInvitation(
    String invitationId,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await Supabase.instance.client
        .from('buddy_invitations')
        .select('*, inviter:inviter_id(id, username, avatar_url)')
        .eq('id', invitationId)
        .eq('invitee_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }
}
