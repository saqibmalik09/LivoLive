import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/features/invite_earn/data/invite_earn_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteEarnSummary {
  const InviteEarnSummary({
    required this.shortId,
    required this.wheelDraws,
    required this.totalInvites,
    required this.weekInvites,
    required this.claimedMilestones,
    required this.records,
  });

  final String shortId;
  final int wheelDraws;
  final int totalInvites;
  final int weekInvites;
  final Set<int> claimedMilestones;
  final List<InviteRecord> records;

  factory InviteEarnSummary.fromJson(Map<String, dynamic> json) {
    final claimed = <int>{};
    final rawClaimed = json['claimed_milestones'];
    if (rawClaimed is List) {
      for (final e in rawClaimed) {
        final n = int.tryParse(e.toString());
        if (n != null) claimed.add(n);
      }
    }
    final records = <InviteRecord>[];
    final rawRecords = json['records'];
    if (rawRecords is List) {
      for (final e in rawRecords) {
        if (e is Map) {
          records.add(InviteRecord.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return InviteEarnSummary(
      shortId: json['short_id']?.toString() ?? '',
      wheelDraws: (json['wheel_draws'] as num?)?.toInt() ?? 0,
      totalInvites: (json['total_invites'] as num?)?.toInt() ?? 0,
      weekInvites: (json['week_invites'] as num?)?.toInt() ?? 0,
      claimedMilestones: claimed,
      records: records,
    );
  }

  static const empty = InviteEarnSummary(
    shortId: '',
    wheelDraws: 0,
    totalInvites: 0,
    weekInvites: 0,
    claimedMilestones: {},
    records: [],
  );
}

class InviteRecord {
  const InviteRecord({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.shortId,
    required this.createdAt,
    required this.bonusCoins,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final String? shortId;
  final DateTime createdAt;
  final int bonusCoins;

  factory InviteRecord.fromJson(Map<String, dynamic> json) {
    return InviteRecord(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'User',
      avatarUrl: json['avatar_url']?.toString(),
      shortId: json['short_id']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      bonusCoins: (json['register_bonus_coins'] as num?)?.toInt() ?? 0,
    );
  }
}

final inviteEarnSummaryProvider = FutureProvider.autoDispose<InviteEarnSummary>(
  (ref) async {
    final res = await Supabase.instance.client.rpc('get_invite_earn_summary');
    if (res is! Map) return InviteEarnSummary.empty;
    final map = Map<String, dynamic>.from(res);
    if (map['success'] != true) return InviteEarnSummary.empty;
    return InviteEarnSummary.fromJson(map);
  },
);

Future<Map<String, dynamic>> acceptInviteCode(String code) async {
  final res = await Supabase.instance.client.rpc(
    'accept_invite_code',
    params: {'p_code': code.trim()},
  );
  if (res is Map) return Map<String, dynamic>.from(res);
  return {'success': false, 'message': 'Unexpected response'};
}

Future<Map<String, dynamic>> claimInviteMilestone(int invitesNeeded) async {
  final res = await Supabase.instance.client.rpc(
    'claim_invite_milestone',
    params: {'p_invites_needed': invitesNeeded},
  );
  if (res is Map) return Map<String, dynamic>.from(res);
  return {'success': false, 'message': 'Unexpected response'};
}

Future<Map<String, dynamic>> spinInviteWheel() async {
  final res = await Supabase.instance.client.rpc('spin_invite_wheel');
  if (res is Map) return Map<String, dynamic>.from(res);
  return {'success': false, 'message': 'Unexpected response'};
}

int milestoneRewardCoins(InviteMilestone m) {
  final label = m.coinsLabel.toUpperCase().replaceAll(',', '');
  if (label.endsWith('K')) {
    final n = double.tryParse(label.substring(0, label.length - 1)) ?? 0;
    return (n * 1000).round();
  }
  if (label.endsWith('M')) {
    final n = double.tryParse(label.substring(0, label.length - 1)) ?? 0;
    return (n * 1000000).round();
  }
  return int.tryParse(label) ?? 0;
}
