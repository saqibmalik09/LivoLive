import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdateInfo {
  final bool updateRequired;
  final String? downloadUrl;
  final String? minVersion;
  final String? currentVersion;
  final bool isForceUpdate;

  AppUpdateInfo({
    required this.updateRequired,
    this.downloadUrl,
    this.minVersion,
    this.currentVersion,
    this.isForceUpdate = true,
  });

  factory AppUpdateInfo.noUpdate(String currentVersion) {
    return AppUpdateInfo(updateRequired: false, currentVersion: currentVersion);
  }
}

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AsyncValue<AppUpdateInfo>>((ref) {
      return AppUpdateNotifier();
    });

class AppUpdateNotifier extends StateNotifier<AsyncValue<AppUpdateInfo>> {
  AppUpdateNotifier() : super(const AsyncValue.loading()) {
    checkVersion();
  }

  Future<void> checkVersion() async {
    if (kIsWeb) {
      state = AsyncValue.data(AppUpdateInfo.noUpdate('1.0.0'));
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion =
          "${packageInfo.version}+${packageInfo.buildNumber}";

      String platformName = '';
      if (Platform.isAndroid) {
        platformName = 'android';
      } else if (Platform.isIOS) {
        platformName = 'ios';
      } else {
        state = AsyncValue.data(AppUpdateInfo.noUpdate(currentVersion));
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('app_versions')
          .select('min_version, download_url, is_force_update')
          .eq('platform', platformName)
          .maybeSingle();

      if (response == null) {
        state = AsyncValue.data(AppUpdateInfo.noUpdate(currentVersion));
        return;
      }

      final String minVersion = response['min_version'] as String;
      final String downloadUrl = response['download_url'] as String;
      final bool isForceUpdate = response['is_force_update'] as bool? ?? true;

      final isOutdated = _compareVersions(currentVersion, minVersion) < 0;

      state = AsyncValue.data(
        AppUpdateInfo(
          updateRequired: isOutdated,
          downloadUrl: downloadUrl,
          minVersion: minVersion,
          currentVersion: currentVersion,
          isForceUpdate: isForceUpdate,
        ),
      );
    } catch (e, stack) {
      debugPrint('Error checking app version: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  int _compareVersions(String v1, String v2) {
    final parts1Clean = v1.split('+')[0].split('.');
    final parts2Clean = v2.split('+')[0].split('.');

    for (int i = 0; i < 3; i++) {
      final int val1 = i < parts1Clean.length
          ? (int.tryParse(parts1Clean[i]) ?? 0)
          : 0;
      final int val2 = i < parts2Clean.length
          ? (int.tryParse(parts2Clean[i]) ?? 0)
          : 0;

      if (val1 < val2) return -1;
      if (val1 > val2) return 1;
    }

    final build1Str = v1.contains('+') ? v1.split('+')[1] : null;
    final build2Str = v2.contains('+') ? v2.split('+')[1] : null;

    if (build1Str != null || build2Str != null) {
      final int build1 = build1Str != null ? (int.tryParse(build1Str) ?? 0) : 0;
      final int build2 = build2Str != null ? (int.tryParse(build2Str) ?? 0) : 0;
      if (build1 < build2) return -1;
      if (build1 > build2) return 1;
    }

    return 0;
  }
}
