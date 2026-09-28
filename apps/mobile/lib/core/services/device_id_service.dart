import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  DeviceIdService._();

  static const _deviceKey = 'installation_device_id';
  static const _bannedFlagKey = 'device_ban_active';
  static const _bannedReasonKey = 'device_ban_reason';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _androidIdPlugin = AndroidId();

  static String? _cachedId;
  static String? _cachedHardwareId;

  static Future<String> getOrCreateDeviceId() async {
    if (_cachedId != null && _cachedId!.isNotEmpty) return _cachedId!;

    try {
      final existing = await _storage.read(key: _deviceKey);
      if (existing != null && existing.trim().length >= 8) {
        _cachedId = existing.trim();
        return _cachedId!;
      }
    } catch (e) {
      debugPrint('[DeviceIdService] read failed: $e');
    }

    final created = const Uuid().v4();
    try {
      await _storage.write(key: _deviceKey, value: created);
    } catch (e) {
      debugPrint('[DeviceIdService] write failed: $e');
    }
    _cachedId = created;
    return created;
  }

  static Future<String?> getHardwareId() async {
    if (_cachedHardwareId != null && _cachedHardwareId!.isNotEmpty) {
      return _cachedHardwareId;
    }
    try {
      if (Platform.isAndroid) {
        final id = (await _androidIdPlugin.getId())?.trim() ?? '';
        if (id.length >= 8) {
          _cachedHardwareId = id;
          return id;
        }
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final id = (info.identifierForVendor ?? '').trim();
        if (id.length >= 8) {
          _cachedHardwareId = id;
          return id;
        }
      }
    } catch (e) {
      debugPrint('[DeviceIdService] getHardwareId failed: $e');
    }
    return null;
  }

  static Future<String?> getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final t = token?.trim() ?? '';
      if (t.length >= 20) return t;
    } catch (e) {
      debugPrint('[DeviceIdService] getFcmToken failed: $e');
    }
    return null;
  }

  static Future<Map<String, String?>> collectSignals() async {
    final installId = await getOrCreateDeviceId();
    final androidId = await getHardwareId();
    final fcm = await getFcmToken();
    return {'install_id': installId, 'android_id': androidId, 'fcm_token': fcm};
  }

  static Future<void> markBanned({String? reason}) async {
    try {
      await _storage.write(key: _bannedFlagKey, value: '1');
      await _storage.write(key: _bannedReasonKey, value: reason?.trim() ?? '');
    } catch (e) {
      debugPrint('[DeviceIdService] markBanned failed: $e');
    }
  }

  static Future<void> clearBannedMark() async {
    try {
      await _storage.delete(key: _bannedFlagKey);
      await _storage.delete(key: _bannedReasonKey);
    } catch (e) {
      debugPrint('[DeviceIdService] clearBannedMark failed: $e');
    }
  }

  static Future<bool> isLocallyMarkedBanned() async {
    try {
      final v = await _storage.read(key: _bannedFlagKey);
      return v == '1';
    } catch (_) {
      return false;
    }
  }

  static Future<String?> localBanReason() async {
    try {
      final v = await _storage.read(key: _bannedReasonKey);
      final t = v?.trim() ?? '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }
}
