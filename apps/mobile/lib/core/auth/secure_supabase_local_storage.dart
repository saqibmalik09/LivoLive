import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/auth/boot_session.dart';
import 'package:sk_live/core/services/auth_service.dart';

class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({
    required this.persistSessionKey,
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ) {
    instance = this;
  }

  static SecureSupabaseLocalStorage? instance;

  final String persistSessionKey;
  final FlutterSecureStorage _storage;

  String get _backupKey => '${persistSessionKey}_backup';

  @override
  Future<void> initialize() async {
    try {
      final existing = await _storage.read(key: persistSessionKey);
      if (existing != null && existing.isNotEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy == null || legacy.isEmpty) return;

      await _storage.write(key: persistSessionKey, value: legacy);
      await _storage.write(key: _backupKey, value: legacy);
      await prefs.remove(persistSessionKey);
      debugPrint('[AuthStorage] migrated session from SharedPreferences');
    } catch (e) {
      debugPrint('[AuthStorage] migrate skipped: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final primary = await _storage.read(key: persistSessionKey);
    if (primary != null && primary.isNotEmpty) return true;
    final backup = await _storage.read(key: _backupKey);
    return backup != null && backup.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    final primary = await _storage.read(key: persistSessionKey);
    if (primary != null && primary.isNotEmpty) return primary;
    return _storage.read(key: _backupKey);
  }

  Future<String?> readSessionBackup() => _storage.read(key: _backupKey);

  @override
  Future<void> removePersistedSession() async {
    final userInitiated = AuthService.instance.isUserInitiatedSignOut;
    if (userInitiated) {
      await Future.wait([
        _storage.delete(key: persistSessionKey),
        _storage.delete(key: _backupKey),
      ]);
      unawaited(BootSession.clearCachedUserId());
      return;
    }

    await _storage.delete(key: persistSessionKey);
    debugPrint('[AuthStorage] kept session backup after non-user remove');
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await Future.wait([
      _storage.write(key: persistSessionKey, value: persistSessionString),
      _storage.write(key: _backupKey, value: persistSessionString),
    ]);
    final userId = BootSession.userIdFromPersistedSession(persistSessionString);
    if (userId != null) unawaited(BootSession.rememberUserId(userId));
  }
}
