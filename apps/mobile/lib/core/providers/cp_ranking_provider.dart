import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CPRankingModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final int score;
  final int rank;
  final String? user1Name;
  final String? user1Avatar;
  final String? user2Name;
  final String? user2Avatar;

  CPRankingModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.score,
    required this.rank,
    this.user1Name,
    this.user1Avatar,
    this.user2Name,
    this.user2Avatar,
  });

  factory CPRankingModel.fromJson(Map<String, dynamic> json) {
    return CPRankingModel(
      id: json['id'],
      user1Id: json['user_1_id'],
      user2Id: json['user_2_id'],
      score: json['score'] ?? 0,
      rank: json['rank'] ?? 0,
      user1Name: json['user1']?['username'],
      user1Avatar: json['user1']?['avatar_url'],
      user2Name: json['user2']?['username'],
      user2Avatar: json['user2']?['avatar_url'],
    );
  }
}

final cpRankingsProvider = FutureProvider.family<List<CPRankingModel>, String>((
  ref,
  type,
) async {
  final supabase = Supabase.instance.client;
  try {
    var query = supabase.from('cp_rankings').select('''
          *,
          user1:users!user_1_id(username, avatar_url),
          user2:users!user_2_id(username, avatar_url)
        ''');

    final response = await query.order('score', ascending: false).limit(20);

    return (response as List)
        .map((json) => CPRankingModel.fromJson(json))
        .toList();
  } catch (e) {
    print('Error fetching CP Rankings ($type): $e');
    return [];
  }
});
