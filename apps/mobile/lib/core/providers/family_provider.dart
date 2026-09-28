import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/error_handler.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

class FamilyModel {
  final String id;
  final String name;
  final String? tag;
  final String? avatarUrl;
  final String creatorId;
  final int totalExp;
  final int level;
  final String? announcement;
  final String? leaderName;

  FamilyModel({
    required this.id,
    required this.name,
    this.tag,
    this.avatarUrl,
    required this.creatorId,
    required this.totalExp,
    required this.level,
    this.announcement,
    this.leaderName,
  });

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    String? leader;
    if (json['users'] != null && json['users'] is Map) {
      leader = json['users']['username'];
    }

    return FamilyModel(
      id: json['id'],
      name: json['name'],
      tag: json['tag'],
      avatarUrl: json['avatar_url'],
      creatorId: json['creator_id'],
      totalExp: json['total_exp'] ?? 0,
      level: json['level'] ?? 1,
      announcement: json['announcement'],
      leaderName: leader,
    );
  }
}

final familyCreationCostProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('system_settings')
        .select('value')
        .eq('key', 'family_creation_cost')
        .single();
    return int.parse(response['value'] ?? '200000');
  } catch (e) {
    print('--- [DEBUG] Error fetching cost, using default 200k: $e ---');
    return 200000;
  }
});

final topFamiliesProvider = FutureProvider<List<FamilyModel>>((ref) async {
  final supabase = Supabase.instance.client;

  try {
    print('--- [DEBUG] Fetching Families from Supabase ---');

    final rawResponse = await supabase
        .from('families')
        .select('*')
        .order('total_exp', ascending: false)
        .limit(10);

    print('--- [DEBUG] Raw Supabase Response: $rawResponse ---');
    return (rawResponse as List)
        .map((json) => FamilyModel.fromJson(json))
        .toList();
  } catch (e) {
    print('!!! [DEBUG] Supabase Fetch Error: $e !!!');
    rethrow;
  }
});

final allFamiliesProvider = FutureProvider<List<FamilyModel>>((ref) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('families')
        .select('*, users!creator_id(username)')
        .order('name');
    return (response as List)
        .map((json) => FamilyModel.fromJson(json))
        .toList();
  } catch (e) {
    print('Error fetching all families: $e');
    return [];
  }
});

final userFamilyProvider = FutureProvider<FamilyModel?>((ref) async {
  final supabase = Supabase.instance.client;

  final userProfileAsync = ref.watch(userProfileProvider);
  final userProfile = userProfileAsync.value;

  if (userProfile == null) {
    print('--- [DEBUG] userFamilyProvider: No user profile loaded yet ---');
    return null;
  }

  final familyId = userProfile['family_id'];
  if (familyId == null) {
    print('--- [DEBUG] userFamilyProvider: user has no family_id ---');
    return null;
  }

  try {
    print(
      '--- [DEBUG] userFamilyProvider: Fetching family for ID $familyId ---',
    );
    final response = await supabase
        .from('families')
        .select('*')
        .eq('id', familyId)
        .maybeSingle();

    print('--- [DEBUG] userFamilyProvider Response: $response ---');

    if (response == null) {
      print('--- [DEBUG] userFamilyProvider: Family not found in DB ---');
      return null;
    }

    final family = FamilyModel.fromJson(response);
    print(
      '--- [DEBUG] userFamilyProvider: Found family ${family.name}, level ${family.level} ---',
    );
    return family;
  } catch (e) {
    print('--- [DEBUG] Error fetching user family: $e ---');
    return null;
  }
});

final familyDetailProvider = FutureProvider.family<FamilyModel?, String>((
  ref,
  familyId,
) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('families')
        .select('*')
        .eq('id', familyId)
        .maybeSingle();
    if (response == null) return null;
    return FamilyModel.fromJson(response);
  } catch (e) {
    print('Error fetching family detail: $e');
    return null;
  }
});

final userFamilyRoleProvider = FutureProvider<String?>((ref) async {
  final supabase = Supabase.instance.client;
  final familyAsync = await ref.watch(userFamilyProvider.future);
  final userProfileAsync = await ref.watch(userProfileProvider.future);

  if (familyAsync == null || userProfileAsync == null) return null;

  try {
    final response = await supabase
        .from('family_members')
        .select('role')
        .eq('family_id', familyAsync.id)
        .eq('user_id', userProfileAsync['id'])
        .maybeSingle();
    return response?['role'] as String?;
  } catch (e) {
    print('Error fetching user family role: $e');
    return null;
  }
});

final familyJoinRequestsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      familyId,
    ) async {
      final supabase = Supabase.instance.client;
      try {
        final response = await supabase
            .from('family_join_requests')
            .select('*, users(username, avatar_url, vip_level)')
            .eq('family_id', familyId)
            .eq('status', 'pending')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('Error fetching join requests: $e');
        return [];
      }
    });

final familyMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      familyId,
    ) async {
      final supabase = Supabase.instance.client;
      try {
        final response = await supabase
            .from('family_members')
            .select(
              '*, users(username, avatar_url, user_level, wealth_level, charm_level, vip_level)',
            )
            .eq('family_id', familyId)
            .order('role');
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('Error fetching family members: $e');
        return [];
      }
    });

final familyLevelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('family_level_configs')
        .select('*')
        .order('level', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    print('Error fetching family level configs: $e');
    return [];
  }
});

class FamilyActions {
  static Future<void> createFamily({
    required String name,
    required String tag,
    required bool approvalRequired,
    required String? localImagePath,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw 'User not logged in';

    final existingCreated = await supabase
        .from('families')
        .select('id')
        .eq('creator_id', user.id)
        .maybeSingle();
    if (existingCreated != null) {
      throw 'You have already created a family. You can only create one family.';
    }

    final userRow = await supabase
        .from('users')
        .select('family_id, coins, vip_level')
        .eq('id', user.id)
        .single();
    if (userRow['family_id'] != null) {
      throw 'You are already a member of a family. Leave it first.';
    }

    final int currentCoins = (userRow['coins'] as num?)?.toInt() ?? 0;
    final int vipLevel = (userRow['vip_level'] as num?)?.toInt() ?? 0;

    bool isFree = false;
    if (vipLevel > 0) {
      final vipPlan = await supabase
          .from('vip_plans')
          .select('has_free_family')
          .eq('level', vipLevel)
          .maybeSingle();
      if (vipPlan != null && vipPlan['has_free_family'] == true) {
        isFree = true;
      }
    }

    int cost = 0;
    if (!isFree) {
      try {
        final costRes = await supabase
            .from('system_settings')
            .select('value')
            .eq('key', 'family_creation_cost')
            .single();
        cost = int.parse(costRes['value'] ?? '200000');
      } catch (e) {
        cost = 200000;
      }

      if (currentCoins < cost) {
        throw 'Insufficient coins! Creating a family costs $cost coins.';
      }
    }

    try {
      String? avatarUrl;

      if (localImagePath != null) {
        final file = File(localImagePath);
        final fileExt = localImagePath.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';
        await supabase.storage.from('family-logos').upload(filePath, file);
        avatarUrl = supabase.storage
            .from('family-logos')
            .getPublicUrl(filePath);
      }

      if (!isFree && cost > 0) {
        await supabase
            .from('users')
            .update({'coins': currentCoins - cost})
            .eq('id', user.id);
      }

      final familyData = await supabase
          .from('families')
          .insert({
            'name': name,
            'avatar_url': avatarUrl,
            'creator_id': user.id,
            'announcement': 'Welcome to $name family!',
            'tag': tag,
          })
          .select()
          .single();

      await supabase.from('family_members').insert({
        'family_id': familyData['id'],
        'user_id': user.id,
        'role': 'leader',
      });

      await supabase
          .from('users')
          .update({'family_id': familyData['id']})
          .eq('id', user.id);
    } catch (e) {
      final errorMessage = SupabaseErrorHandler.handle(
        e,
        customMessage: 'Failed to create family',
      );
      throw errorMessage;
    }
  }

  static Future<void> updateFamily({
    required String familyId,
    required String name,
    required String tag,
    required bool approvalRequired,
    required String? localImagePath,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw 'User not logged in';

    try {
      String? avatarUrl;

      if (localImagePath != null) {
        final file = File(localImagePath);
        final fileExt = localImagePath.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '${user.id}/$fileName';
        await supabase.storage.from('family-logos').upload(filePath, file);
        avatarUrl = supabase.storage
            .from('family-logos')
            .getPublicUrl(filePath);
      }

      final updateData = <String, dynamic>{'name': name, 'tag': tag};
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      await supabase.from('families').update(updateData).eq('id', familyId);
    } catch (e) {
      throw 'Failed to update family: $e';
    }
  }

  static Future<void> requestJoin(String familyId) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw 'User not logged in';

    final userRow = await supabase
        .from('users')
        .select('family_id')
        .eq('id', user.id)
        .single();
    if (userRow['family_id'] != null) {
      throw 'You are already a member of a family. Leave it first.';
    }

    final existingReq = await supabase
        .from('family_join_requests')
        .select('id')
        .eq('family_id', familyId)
        .eq('user_id', user.id)
        .eq('status', 'pending')
        .maybeSingle();
    if (existingReq != null) {
      throw 'You already have a pending request for this family.';
    }

    try {
      await supabase.from('family_join_requests').insert({
        'family_id': familyId,
        'user_id': user.id,
        'status': 'pending',
      });
    } catch (e) {
      final errorMessage = SupabaseErrorHandler.handle(
        e,
        customMessage: 'Failed to apply to family',
      );
      throw errorMessage;
    }
  }

  static Future<void> respondToJoinRequest({
    required String requestId,
    required String userId,
    required String familyId,
    required bool accept,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      if (accept) {
        await supabase
            .from('family_join_requests')
            .update({'status': 'accepted'})
            .eq('id', requestId);

        await supabase.from('family_members').insert({
          'family_id': familyId,
          'user_id': userId,
          'role': 'member',
        });

        await supabase
            .from('users')
            .update({'family_id': familyId})
            .eq('id', userId);
      } else {
        await supabase
            .from('family_join_requests')
            .update({'status': 'rejected'})
            .eq('id', requestId);
      }
    } catch (e) {
      throw 'Failed to respond to request: $e';
    }
  }

  static Future<void> updateMemberRole({
    required String memberId,
    required String newRole,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('family_members')
          .update({'role': newRole})
          .eq('id', memberId);
    } catch (e) {
      throw 'Failed to update role: $e';
    }
  }

  static Future<void> removeMember({
    required String memberId,
    required String userId,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('family_members').delete().eq('id', memberId);

      await supabase.from('users').update({'family_id': null}).eq('id', userId);
    } catch (e) {
      throw 'Failed to remove member: $e';
    }
  }

  static Future<void> leaveFamily({required String familyId}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw 'User not logged in';

    try {
      await supabase
          .from('family_members')
          .delete()
          .eq('family_id', familyId)
          .eq('user_id', user.id);

      await supabase
          .from('users')
          .update({'family_id': null})
          .eq('id', user.id);
    } catch (e) {
      throw 'Failed to leave family: $e';
    }
  }
}
