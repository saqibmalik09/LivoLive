import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/app_telemetry.dart';

final telemetryAuthSyncProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (previous, next) {
    if (next.value?.session == null) {
      unawaited(AppTelemetry.clearUser());
    }
  });

  ref.listen(userProfileProvider, (previous, next) {
    final profile = next.valueOrNull;
    final id = profile?['id']?.toString();
    if (id == null || id.isEmpty) return;
    unawaited(
      AppTelemetry.setUser(
        id,
        vipLevel: (profile?['vip_level'] as num?)?.toInt(),
        shortId: profile?['short_id']?.toString(),
      ),
    );
  });
});
