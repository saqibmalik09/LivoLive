import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/device_id_service.dart';
import 'package:sk_live/core/services/auth_service.dart';

final singleDeviceSessionGuardProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<Map<String, dynamic>?>>(userProfileProvider, (
    previous,
    next,
  ) async {
    final profile = next.asData?.value;
    if (profile == null) return;

    final remoteDevice = profile['last_device_id']?.toString().trim() ?? '';
    if (remoteDevice.length < 8) return;

    final session = AuthService.instance.currentSession;
    if (session == null) return;

    final localDevice = await DeviceIdService.getOrCreateDeviceId();
    if (localDevice.isEmpty) return;

    if (remoteDevice == localDevice) return;

    debugPrint(
      '[Auth] last_device_id mismatch local=$localDevice '
      'remote=$remoteDevice — force logout',
    );
    await AuthService.instance.signOutDueToOtherDevice();
  });
});
