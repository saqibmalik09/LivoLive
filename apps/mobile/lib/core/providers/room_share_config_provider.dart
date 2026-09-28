import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/app_constants.dart';

final roomShareBaseUrlProvider = FutureProvider<String>((ref) async {
  try {
    final row = await Supabase.instance.client
        .from('system_settings')
        .select('value')
        .eq('key', 'room_share_base_url')
        .maybeSingle();

    final url = row?['value']?.toString().trim();
    if (url != null &&
        url.isNotEmpty &&
        url.startsWith('http') &&
        !url.contains('supabase.co')) {
      return url.replaceAll(RegExp(r'/+$'), '');
    }
  } catch (e) {}
  return AppConstants.roomSharePublicBaseUrl;
});
