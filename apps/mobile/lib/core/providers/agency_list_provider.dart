import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgencyListItem {
  const AgencyListItem({
    required this.id,
    required this.name,
    required this.agencyCode,
    this.avatarUrl,
    this.countryCode,
    this.description,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String agencyCode;
  final String? avatarUrl;
  final String? countryCode;
  final String? description;
  final int memberCount;
}

final recommendedAgenciesProvider = FutureProvider<List<AgencyListItem>>((
  ref,
) async {
  try {
    final response = await Supabase.instance.client
        .from('agencies')
        .select(
          'id, name, agency_code, users!owner_id(avatar_url, country_code, bio), agency_members(count)',
        )
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((raw) {
      final json = Map<String, dynamic>.from(raw);
      final owner = json['users'] as Map<String, dynamic>? ?? {};
      final members = json['agency_members'];
      var memberCount = 0;
      if (members is List && members.isNotEmpty) {
        memberCount = (members.first['count'] as num?)?.toInt() ?? 0;
      }

      return AgencyListItem(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Agency',
        agencyCode: json['agency_code']?.toString() ?? '',
        avatarUrl: owner['avatar_url'] as String?,
        countryCode: owner['country_code'] as String?,
        description: owner['bio'] as String?,
        memberCount: memberCount,
      );
    }).toList();
  } catch (e) {
    debugPrint('[AgencyList] fetch failed: $e');
    return [];
  }
});
