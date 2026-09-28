import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

final _supabase = Supabase.instance.client;

class AgencyCenterAccess {
  final Map<String, dynamic> agency;
  final String accessRole;

  const AgencyCenterAccess({required this.agency, required this.accessRole});

  String get agencyId => agency['id'] as String;
  bool get isOwner => accessRole == 'owner';
  bool get canManagePayment => isOwner;
  bool get canChangeRoles => isOwner;
}

final agencyCenterAccessProvider =
    FutureProvider.autoDispose<AgencyCenterAccess?>((ref) async {
      ref.watch(authStateProvider);
      final res = await _supabase.rpc('get_my_agency_center');
      final map = Map<String, dynamic>.from(res as Map);
      if (map['success'] != true) return null;
      final agency = Map<String, dynamic>.from(map['agency'] as Map);
      return AgencyCenterAccess(
        agency: agency,
        accessRole: map['access_role']?.toString() ?? 'admin',
      );
    });

final agencyMembersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, agencyId) async {
      final res = await _supabase
          .from('agency_members')
          .select('*, users:user_id(username, avatar_url, id, short_id)')
          .eq('agency_id', agencyId)
          .order('joined_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    });

final agencyNoticesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, agencyId) async {
      final res = await _supabase
          .from('agency_notices')
          .select('*, author:author_id(username, avatar_url)')
          .eq('agency_id', agencyId)
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(res as List);
    });

final agencyApplicationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String agencyId, String status})>((
      ref,
      args,
    ) async {
      final res = args.status == 'all'
          ? await _supabase
                .from('agency_applications')
                .select('*, users:user_id(username, avatar_url, id, short_id)')
                .eq('agency_id', args.agencyId)
                .order('created_at', ascending: false)
          : await _supabase
                .from('agency_applications')
                .select('*, users:user_id(username, avatar_url, id, short_id)')
                .eq('agency_id', args.agencyId)
                .eq('status', args.status)
                .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    });

final agencyMemberEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, agencyId) async {
      final res = await _supabase
          .from('agency_member_events')
          .select(
            '*, users:user_id(username, avatar_url, id, short_id), actor:actor_id(username, id)',
          )
          .eq('agency_id', agencyId)
          .order('created_at', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(res as List);
    });

Future<Map<String, Map<String, dynamic>>> fetchAgencyMembersPeriodStats({
  required String agencyId,
  String? periodId,
  String? userId,
}) async {
  final res = await _supabase.rpc(
    'get_agency_members_period_stats',
    params: {
      'p_agency_id': agencyId,
      'p_period_id': periodId,
      if (userId != null) 'p_user_id': userId,
    },
  );
  final map = Map<String, dynamic>.from(res as Map);
  if (map['success'] != true) return {};
  final out = <String, Map<String, dynamic>>{};
  for (final row in map['members'] as List? ?? []) {
    final m = Map<String, dynamic>.from(row as Map);
    final id = m['user_id']?.toString();
    if (id != null) out[id] = m;
  }
  return out;
}

class AgencyCenterActions {
  final Ref ref;
  AgencyCenterActions(this.ref);

  Future<Map<String, dynamic>> setMemberRole({
    required String agencyId,
    required String userId,
    required String role,
  }) async {
    final res = await _supabase.rpc(
      'set_agency_member_role',
      params: {'p_agency_id': agencyId, 'p_user_id': userId, 'p_role': role},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(agencyMembersProvider(agencyId));
      ref.invalidate(agencyCenterAccessProvider);
    }
    return map;
  }

  Future<Map<String, dynamic>> postNotice({
    required String agencyId,
    required String title,
    required String body,
  }) async {
    final res = await _supabase.rpc(
      'post_agency_notice',
      params: {'p_agency_id': agencyId, 'p_title': title, 'p_body': body},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] == true) {
      ref.invalidate(agencyNoticesProvider(agencyId));
    }
    return map;
  }

  Future<void> updateAgencyInfo({
    required String agencyId,
    required String name,
    required String announcement,
    required String attribute,
    String? whatsapp,
    String? contactEmail,
    String? logoUrl,
    bool clearLogo = false,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'announcement': announcement,
      'attribute': attribute,
      'whatsapp': whatsapp,
      'contact_email': contactEmail,
    };
    if (clearLogo) {
      payload['logo_url'] = null;
    } else if (logoUrl != null) {
      payload['logo_url'] = logoUrl;
    }
    await _supabase.from('agencies').update(payload).eq('id', agencyId);
    ref.invalidate(agencyCenterAccessProvider);
  }

  Future<void> updateAnnouncement({
    required String agencyId,
    required String announcement,
  }) async {
    await _supabase
        .from('agencies')
        .update({'announcement': announcement})
        .eq('id', agencyId);
    ref.invalidate(agencyCenterAccessProvider);
  }

  Future<void> removeHost({
    required String agencyId,
    required String userId,
  }) async {
    final res = await _supabase.rpc(
      'remove_agency_host',
      params: {'p_agency_id': agencyId, 'p_user_id': userId},
    );
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] != true) {
      throw Exception(map['message']?.toString() ?? 'Failed to remove host');
    }
    ref.invalidate(agencyMembersProvider(agencyId));
    ref.invalidate(agencyMemberEventsProvider(agencyId));
  }

  Future<void> leaveMyAgency() async {
    final res = await _supabase.rpc('leave_my_agency');
    final map = Map<String, dynamic>.from(res as Map);
    if (map['success'] != true) {
      throw Exception(map['message']?.toString() ?? 'Failed to leave agency');
    }
    final agencyId = map['agency_id']?.toString();
    if (agencyId != null) {
      ref.invalidate(agencyMembersProvider(agencyId));
      ref.invalidate(agencyMemberEventsProvider(agencyId));
    }
    ref.invalidate(agencyCenterAccessProvider);
  }
}

final agencyCenterActionsProvider = Provider((ref) => AgencyCenterActions(ref));
