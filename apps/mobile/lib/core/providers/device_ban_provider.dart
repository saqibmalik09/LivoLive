import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/services/device_id_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceBanStatus {
  const DeviceBanStatus({
    required this.isBanned,
    this.reason,
    this.deviceId,
    this.matched,
  });

  final bool isBanned;
  final String? reason;
  final String? deviceId;
  final String? matched;

  static const clear = DeviceBanStatus(isBanned: false);
}

final _deviceBanAuthTickProvider = StreamProvider<String?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession?.user.id;
  await for (final event in auth.onAuthStateChange) {
    yield event.session?.user.id;
  }
});

final deviceBanProvider =
    AsyncNotifierProvider<DeviceBanNotifier, DeviceBanStatus>(
      DeviceBanNotifier.new,
    );

class DeviceBanNotifier extends AsyncNotifier<DeviceBanStatus> {
  @override
  Future<DeviceBanStatus> build() async {
    ref.watch(_deviceBanAuthTickProvider);

    final deviceId = await DeviceIdService.getOrCreateDeviceId();
    final localBanned = await DeviceIdService.isLocallyMarkedBanned();
    final localReason = await DeviceIdService.localBanReason();
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (localBanned) {
        final remote = await _checkRemote();
        if (remote != null) {
          if (remote.isBanned) {
            await DeviceIdService.markBanned(reason: remote.reason);
            return remote;
          }
          await DeviceIdService.clearBannedMark();
          return DeviceBanStatus(isBanned: false, deviceId: deviceId);
        }
        return DeviceBanStatus(
          isBanned: true,
          reason: localReason,
          deviceId: deviceId,
        );
      }
      return DeviceBanStatus(isBanned: false, deviceId: deviceId);
    }

    return registerNow();
  }

  Future<DeviceBanStatus> registerNow() async {
    final signals = await DeviceIdService.collectSignals();
    final deviceId = signals['install_id']!;
    try {
      final raw = await Supabase.instance.client.rpc(
        'register_my_device',
        params: {
          'p_device_id': deviceId,
          'p_android_id': signals['android_id'],
          'p_fcm_token': signals['fcm_token'],
        },
      );
      final map = _asMap(raw);
      final banned = map['banned'] == true;
      final reason = map['reason']?.toString();
      final matched = map['matched']?.toString();

      if (banned) {
        await DeviceIdService.markBanned(reason: reason);
        final status = DeviceBanStatus(
          isBanned: true,
          reason: reason,
          deviceId: deviceId,
          matched: matched,
        );
        state = AsyncData(status);
        return status;
      }

      await DeviceIdService.clearBannedMark();
      final status = DeviceBanStatus(isBanned: false, deviceId: deviceId);
      state = AsyncData(status);
      return status;
    } catch (e, st) {
      debugPrint('[deviceBanProvider] register_my_device failed: $e');
      final localBanned = await DeviceIdService.isLocallyMarkedBanned();
      if (localBanned) {
        final status = DeviceBanStatus(
          isBanned: true,
          reason: await DeviceIdService.localBanReason(),
          deviceId: deviceId,
        );
        state = AsyncData(status);
        return status;
      }
      state = AsyncError(e, st);
      return DeviceBanStatus(isBanned: false, deviceId: deviceId);
    }
  }

  Future<DeviceBanStatus?> _checkRemote() async {
    try {
      final signals = await DeviceIdService.collectSignals();
      final deviceId = signals['install_id']!;
      final raw = await Supabase.instance.client.rpc(
        'check_device_banned',
        params: {
          'p_device_id': deviceId,
          'p_android_id': signals['android_id'],
          'p_fcm_token': signals['fcm_token'],
        },
      );
      final map = _asMap(raw);
      return DeviceBanStatus(
        isBanned: map['banned'] == true,
        reason: map['reason']?.toString(),
        deviceId: deviceId,
        matched: map['matched']?.toString(),
      );
    } catch (e) {
      debugPrint('[deviceBanProvider] check_device_banned failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }
}
