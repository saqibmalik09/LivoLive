import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/provider_cache.dart';
import 'package:sk_live/core/util/user_search_query.dart';

class CPNestItemModel {
  final String id;
  final String name;
  final int price;
  final String? imageUrl;
  final String? svgaUrl;
  final String? category;

  CPNestItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.svgaUrl,
    this.category,
  });

  factory CPNestItemModel.fromJson(Map<String, dynamic> json) {
    return CPNestItemModel(
      id: json['id'],
      name: json['name'],
      price: json['price'] ?? 0,
      imageUrl: json['image_url'],
      svgaUrl: json['svga_url'],
      category: json['category'],
    );
  }

  String? get displaySvgaUrl {
    final s = svgaUrl?.trim();
    if (s != null && s.isNotEmpty) return s;
    final img = imageUrl?.trim();
    if (img != null && img.toLowerCase().contains('.svga')) return img;
    return null;
  }

  String? get displayImageUrl {
    if (displaySvgaUrl != null) return null;
    final img = imageUrl?.trim();
    if (img == null || img.isEmpty) return null;
    return img;
  }
}

final cpNestItemsProvider = FutureProvider<List<CPNestItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('cp_nest_items')
        .select('*')
        .order('price', ascending: true);

    return (response as List)
        .map((json) => CPNestItemModel.fromJson(json))
        .toList();
  } catch (e) {
    print('Error fetching CP Nest items: $e');
    return [];
  }
});

final cpLevelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('cp_level_configs')
        .select('*')
        .order('level', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});

final cpNestUserSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
      cacheFamilyEntry(ref, ttl: const Duration(minutes: 2));
      final supabase = Supabase.instance.client;
      try {
        final trimmed = query.trim();
        if (trimmed.isEmpty) {
          final response = await supabase
              .from('users')
              .select('id, username, avatar_url, user_level, short_id')
              .order('user_level', ascending: false)
              .limit(20);
          return List<Map<String, dynamic>>.from(response);
        }

        if (!isUserSearchQueryReady(trimmed)) return [];

        const select = 'id, username, avatar_url, user_level, short_id';
        if (isNumericUidQuery(trimmed)) {
          final response = await supabase
              .from('users')
              .select(select)
              .eq('short_id', int.parse(trimmed))
              .limit(5);
          return List<Map<String, dynamic>>.from(response);
        }

        final response = await supabase
            .from('users')
            .select(select)
            .ilike('username', '%$trimmed%')
            .limit(20);
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('Error searching users: $e');
        return [];
      }
    });

class CPNestActions {
  static Future<void> sendProposal({
    required String itemId,
    required int price,
    required String receiverId,
  }) async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) throw 'User not logged in';

    final res = await supabase.rpc(
      'send_cp_proposal',
      params: {'p_item_id': itemId, 'p_receiver_id': receiverId},
    );

    final map = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    if (map['success'] != true) {
      throw (map['message'] ?? 'Failed to send proposal').toString();
    }
  }

  static Future<void> respondToProposal({
    required String proposalId,
    required bool accept,
  }) async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) throw 'User not logged in';

    final res = await supabase.rpc(
      'respond_to_cp_proposal',
      params: {'p_proposal_id': proposalId, 'p_accept': accept},
    );

    final map = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    if (map['success'] != true) {
      throw (map['message'] ?? 'Failed to respond to proposal').toString();
    }
  }

  static Future<void> breakupCouple() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) throw 'User not logged in';

    final res = await supabase.rpc('breakup_couple');

    final map = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    if (map['success'] != true) {
      throw (map['message'] ?? 'Failed to break up').toString();
    }
  }
}

final currentCoupleProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final response = await supabase
        .from('couples')
        .select(
          '*, user1:user1_id(id, username, avatar_url), user2:user2_id(id, username, avatar_url)',
        )
        .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
        .maybeSingle();

    return response;
  } catch (e) {
    return null;
  }
});

final pendingProposalsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  try {
    final response = await supabase
        .from('cp_proposals')
        .select(
          '*, sender:sender_id(id, username, avatar_url), item:item_id(*)',
        )
        .eq('receiver_id', user.id)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toIso8601String());

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});
