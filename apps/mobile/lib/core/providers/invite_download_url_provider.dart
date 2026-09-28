import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/features/invite_earn/data/invite_earn_config.dart';

final inviteDownloadUrlProvider = FutureProvider<String>((ref) async {
  try {
    final row = await Supabase.instance.client
        .from('system_settings')
        .select('value')
        .eq('key', 'invite_download_url')
        .maybeSingle();

    final url = row?['value']?.toString().trim();
    if (url != null &&
        url.isNotEmpty &&
        url.startsWith('http') &&
        !url.contains('supabase.co')) {
      return url.replaceAll(RegExp(r'/+$'), '');
    }
  } catch (_) {}
  return InviteEarnConfig.downloadUrl;
});
