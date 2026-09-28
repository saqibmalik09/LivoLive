import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VoiceBackend { orbit }

class VoiceBackendConfig {
  const VoiceBackendConfig({
    required this.backend,
    this.orbitApiUrl = '',
    this.orbitLivekitUrl = '',
  });

  final VoiceBackend backend;
  final String orbitApiUrl;
  final String orbitLivekitUrl;

  bool get isOrbit => true;

  static const fallback = VoiceBackendConfig(backend: VoiceBackend.orbit);
}

final voiceBackendConfigProvider = FutureProvider<VoiceBackendConfig>((
  ref,
) async {
  try {
    final rows = await Supabase.instance.client
        .from('system_settings')
        .select('key, value')
        .inFilter('key', [
          'voice_backend',
          'orbit_api_url',
          'orbit_livekit_url',
        ]);
    final map = <String, String>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      map[row['key'] as String] = (row['value'] as String?)?.trim() ?? '';
    }
    return VoiceBackendConfig(
      backend: VoiceBackend.orbit,
      orbitApiUrl: map['orbit_api_url'] ?? '',
      orbitLivekitUrl: map['orbit_livekit_url'] ?? '',
    );
  } catch (e) {
    return VoiceBackendConfig.fallback;
  }
});
