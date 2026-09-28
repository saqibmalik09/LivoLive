import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/user_search_query.dart';

final supabase = Supabase.instance.client;

class BusinessStaffProfile {
  final String id;
  final String userId;
  final String role;
  final String staffCode;
  final String? parentStaffId;
  final bool isActive;

  const BusinessStaffProfile({
    required this.id,
    required this.userId,
    required this.role,
    required this.staffCode,
    this.parentStaffId,
    required this.isActive,
  });

  factory BusinessStaffProfile.fromJson(Map<String, dynamic> json) {
    return BusinessStaffProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      staffCode: json['staff_code'] as String,
      parentStaffId: json['parent_staff_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get normalizedRole {
    if (role == 'bd_admin') return 'county_admin';
    return role;
  }

  String get roleLabel {
    switch (normalizedRole) {
      case 'super_bd':
        return 'Super Admin';
      case 'county_admin':
        return 'County Admin';
      case 'bd':
        return 'BD';
      case 'assistant':
        return 'Assistant';
      case 'customer_service':
        return 'Customer Service';
      default:
        return role;
    }
  }

  bool get hasCenterPanel {
    switch (normalizedRole) {
      case 'super_bd':
      case 'county_admin':
      case 'bd':
        return true;
      default:
        return false;
    }
  }

  String? get childRole {
    switch (normalizedRole) {
      case 'super_bd':
        return 'county_admin';
      case 'county_admin':
        return 'bd';
      default:
        return null;
    }
  }

  bool get isSuperBd => isActive && normalizedRole == 'super_bd';
}

bool isActiveSuperBd(BusinessStaffProfile? staff) => staff?.isSuperBd == true;

Future<bool> currentUserIsSuperBd() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;
  return isUserActiveSuperBd(userId);
}

Future<bool> isUserActiveSuperBd(String userId) async {
  if (userId.isEmpty) return false;
  try {
    final res = await supabase
        .from('business_staff')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true)
        .eq('role', 'super_bd')
        .maybeSingle();
    return res != null;
  } catch (e) {
    debugPrint('[isUserActiveSuperBd] $e');
    return false;
  }
}

final myBusinessStaffProvider = FutureProvider<BusinessStaffProfile?>((
  ref,
) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final res = await supabase
      .from('business_staff')
      .select()
      .eq('user_id', userId)
      .eq('is_active', true)
      .maybeSingle();

  if (res == null) return null;
  return BusinessStaffProfile.fromJson(Map<String, dynamic>.from(res));
});

final staffTeamProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      staffId,
    ) async {
      final res = await supabase
          .from('business_staff')
          .select(
            'id, role, staff_code, is_active, users:user_id(id, username, short_id, avatar_url)',
          )
          .eq('parent_staff_id', staffId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    });

final staffAgencyApplicationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      staffId,
    ) async {
      final myStaff = await ref.watch(myBusinessStaffProvider.future);
      final role = myStaff?.normalizedRole;

      if (role == 'super_bd' || role == 'county_admin') {
        final res = await supabase.rpc('list_subtree_agency_applications');
        final list = (res is List) ? res : <dynamic>[];
        return list.map((row) {
          final m = Map<String, dynamic>.from(row as Map);
          m['users'] = {
            'username': m['username'],
            'short_id': m['short_id'],
            'avatar_url': m['avatar_url'],
          };
          return m;
        }).toList();
      }

      final res = await supabase
          .from('user_applications')
          .select('*, users:user_id(username, short_id, avatar_url)')
          .eq('type', 'agency')
          .eq('status', 'pending')
          .eq('target_staff_id', staffId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    });

final staffEarningsProvider = FutureProvider.family<int, BusinessStaffProfile>((
  ref,
  staff,
) async {
  String? staffColumn;
  switch (staff.normalizedRole) {
    case 'bd':
      staffColumn = 'bd_staff_id';
      break;
    case 'county_admin':
      staffColumn = 'bd_admin_staff_id';
      break;
    case 'super_bd':
      staffColumn = 'super_bd_staff_id';
      break;
    default:
      return 0;
  }

  final amountColumn = staff.normalizedRole == 'bd'
      ? 'bd_amount'
      : staff.normalizedRole == 'county_admin'
      ? 'bd_admin_amount'
      : 'super_bd_amount';

  final logs = await supabase
      .from('earning_logs')
      .select(amountColumn)
      .eq(staffColumn, staff.id);

  var total = 0;
  for (final row in (logs as List)) {
    total += (row[amountColumn] as num?)?.toInt() ?? 0;
  }
  return total;
});

class StaffActions {
  static Future<void> _audit({
    required String action,
    String? targetType,
    String? targetId,
    String? summary,
    Map<String, dynamic>? metadata,
    bool success = true,
  }) async {
    try {
      await supabase.rpc(
        'log_admin_audit',
        params: {
          'p_action': action,
          'p_target_type': targetType,
          'p_target_id': targetId,
          'p_summary': summary,
          'p_metadata': metadata ?? <String, dynamic>{},
          'p_success': success,
          'p_source': 'sklive-flutter',
        },
      );
    } catch (e) {
      debugPrint('log_admin_audit failed: $e');
    }
  }

  static bool _rpcOk(Map<String, dynamic> res) => res['success'] != false;

  static Future<Map<String, dynamic>> createSubStaff({
    required String parentStaffId,
    required String targetUserId,
    required String role,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase.rpc(
      'create_business_staff',
      params: {
        'p_target_user_id': targetUserId,
        'p_role': role,
        'p_parent_staff_id': parentStaffId,
        'p_created_by_user_id': userId,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      final promoteAction = switch (role) {
        'super_bd' => 'user.promote_super_bd',
        'county_admin' || 'bd_admin' => 'user.promote_county_admin',
        'bd' => 'user.promote_bd',
        _ => 'staff.create',
      };
      await _audit(
        action: promoteAction,
        targetType: 'user',
        targetId: targetUserId,
        summary: 'Created $role staff (Mobile app)',
        metadata: {
          'role': role,
          'parent_staff_id': parentStaffId,
          'staff_code': map['staff_code'],
        },
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>> approveAgencyApplication(
    String applicationId,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase.rpc(
      'approve_agency_application',
      params: {
        'p_application_id': applicationId,
        'p_approver_user_id': userId,
        'p_is_official': false,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: 'agency.application_approve',
        targetType: 'agency_application',
        targetId: applicationId,
        summary: 'Approved agency request (Mobile app)',
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>> rejectAgencyApplication(
    String applicationId,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase.rpc(
      'reject_agency_application',
      params: {
        'p_application_id': applicationId,
        'p_approver_user_id': userId,
        'p_is_official': false,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: 'agency.application_reject',
        targetType: 'agency_application',
        targetId: applicationId,
        summary: 'Rejected agency request (Mobile app)',
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>> deactivateStaff(String staffId) async {
    final response = await supabase.rpc(
      'super_bd_deactivate_staff',
      params: {'p_staff_id': staffId},
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: 'staff.deactivate',
        targetType: 'staff',
        targetId: staffId,
        summary: 'Deactivated staff (Mobile app)',
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>> deactivateAgency(String agencyId) async {
    final response = await supabase.rpc(
      'super_bd_deactivate_agency',
      params: {'p_agency_id': agencyId},
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: 'agency.deactivate',
        targetType: 'agency',
        targetId: agencyId,
        summary: 'Deactivated agency (Mobile app)',
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>> createOwnAgency(String agencyName) async {
    final userId = supabase.auth.currentUser?.id;
    final response = await supabase.rpc(
      'create_staff_agency',
      params: {'p_staff_user_id': userId, 'p_agency_name': agencyName},
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: 'agency.create',
        targetType: 'user',
        targetId: userId,
        summary: 'Created agency "$agencyName" (Mobile app)',
        metadata: {'agency_code': map['agency_code']},
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>> createAgencyForOwnerUnderBd({
    required String ownerUserId,
    required String bdRef,
  }) async {
    final response = await supabase.rpc(
      'create_agency_for_owner_under_bd',
      params: {
        'p_owner_user_ref': ownerUserId.trim(),
        'p_bd_ref': bdRef.trim(),
      },
    );
    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: 'agency.create',
        targetType: 'agency',
        targetId: map['agency_id']?.toString(),
        summary:
            'Created agency for user $ownerUserId under BD $bdRef (Mobile app)',
        metadata: {
          'agency_code': map['agency_code'],
          'created': map['created'],
        },
      );
    }
    return map;
  }

  static Future<Map<String, dynamic>?> getMyOwnedAgency() async {
    try {
      final response = await supabase.rpc('get_my_owned_agency');
      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        if (map['id'] != null) return map;
      }
    } catch (e) {
      debugPrint('getMyOwnedAgency rpc failed: $e');
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final row = await supabase
          .from('agencies')
          .select(
            'id, name, agency_code, is_active, owner_id, sponsor_staff_id',
          )
          .eq('owner_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) return Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('getMyOwnedAgency fallback failed: $e');
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (!isUserSearchQueryReady(trimmed)) return [];

    final dynamic res;
    if (isNumericUidQuery(trimmed)) {
      res = await supabase
          .from('users')
          .select('id, username, short_id, avatar_url')
          .eq('short_id', int.parse(trimmed))
          .limit(8);
    } else {
      res = await supabase
          .from('users')
          .select('id, username, short_id, avatar_url')
          .ilike('username', '%$trimmed%')
          .limit(8);
    }
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>> setVipForUser({
    required String targetUserId,
    required int vipLevel,
  }) async {
    final response = await supabase.rpc(
      'super_bd_set_user_vip',
      params: {
        'p_target_user_id': targetUserId,
        'p_vip_level': vipLevel,
        'p_days': 30,
        'p_replace_expiry': false,
      },
    );

    final map = Map<String, dynamic>.from(response as Map);
    if (_rpcOk(map)) {
      await _audit(
        action: vipLevel == 0 ? 'user.vip_remove' : 'user.vip_set',
        targetType: 'user',
        targetId: targetUserId,
        summary: vipLevel == 0
            ? 'Removed VIP (Mobile app)'
            : 'Set VIP level $vipLevel (30 days, Mobile app)',
        metadata: {
          'vip_level': vipLevel,
          'vip_days': 30,
          'vip_until': map['vip_until'] ?? null,
        },
      );
    }

    return map;
  }

  static Future<Map<String, dynamic>> removeVipForUser({
    required String targetUserId,
  }) async {
    return setVipForUser(targetUserId: targetUserId, vipLevel: 0);
  }
}
