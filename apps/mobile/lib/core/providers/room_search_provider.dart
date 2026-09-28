import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/user_search_query.dart';

final roomSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      query,
    ) async {
      final q = query.trim();
      final isUuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(q);

      if (!isUserSearchQueryReady(q) && !isUuid) return [];

      final supabase = Supabase.instance.client;
      const select =
          '*, host:host_id(username, avatar_url, short_id, country_code)';
      final merged = <String, Map<String, dynamic>>{};

      void addRoom(Map<String, dynamic> raw) {
        final id = raw['id'].toString();
        final host = raw['host'] as Map<String, dynamic>?;
        merged[id] = {
          ...raw,
          'host_name': host?['username'] ?? raw['host_name'],
          'host_avatar': host?['avatar_url'] ?? raw['host_avatar'],
          'host_country_code':
              host?['country_code'] ?? raw['host_country_code'],
        };
      }

      if (!isNumericUidQuery(q) && q.length >= 2) {
        final byTitle = await supabase
            .from('rooms')
            .select(select)
            .eq('is_active', true)
            .ilike('title', '%$q%')
            .limit(20);
        for (final row in byTitle) {
          addRoom(Map<String, dynamic>.from(row));
        }
      }

      if (isNumericUidQuery(q)) {
        final sid = int.tryParse(q);
        if (sid != null) {
          final byShort = await supabase
              .from('rooms')
              .select(select)
              .eq('short_id', sid)
              .eq('is_active', true)
              .maybeSingle();
          if (byShort != null) addRoom(Map<String, dynamic>.from(byShort));
        }
      }

      if (isUuid) {
        final byId = await supabase
            .from('rooms')
            .select(select)
            .eq('id', q)
            .eq('is_active', true)
            .maybeSingle();
        if (byId != null) addRoom(Map<String, dynamic>.from(byId));
      }

      final compact = q.replaceAll('-', '').toLowerCase();
      if (compact.length >= 4 && !isNumericUidQuery(q)) {
        final active = await supabase
            .from('rooms')
            .select(select)
            .eq('is_active', true)
            .order('online_users_count', ascending: false)
            .limit(100);
        for (final row in active) {
          final idCompact = row['id']
              .toString()
              .replaceAll('-', '')
              .toLowerCase();
          if (idCompact.contains(compact)) {
            addRoom(Map<String, dynamic>.from(row));
          }
        }
      }

      return merged.values.toList();
    });
