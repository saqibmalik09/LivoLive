/*
 * Livo / SK Live Party
 * App maintenance & design by NoxLab AI - https://noxlabai.com
 * Contact: https://noxlabai.com/quote | https://noxlabai.com/book
 * (c) 2026 NoxLab AI - maintenance and design updates
 */
import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:sk_live/core/auth/boot_session.dart';
import 'package:sk_live/core/auth/secure_supabase_local_storage.dart';
import 'package:sk_live/core/l10n/app_locale.dart';
import 'package:sk_live/core/providers/locale_provider.dart';
import 'package:sk_live/core/providers/single_device_session_guard.dart';
import 'package:sk_live/core/providers/telemetry_auth_sync.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/services/background_service.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/services/notification_service.dart';
import 'package:sk_live/core/services/orbit_voice_session_service.dart';
import 'package:sk_live/core/services/room_deep_link_service.dart';
import 'package:sk_live/core/services/update_service.dart';
import 'package:sk_live/core/theme/app_theme.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/svga_cache.dart';
import 'package:sk_live/core/widgets/big_gift_patti_broadcast_host.dart';
import 'package:sk_live/core/widgets/dm_gateway_host.dart';
import 'package:sk_live/core/widgets/force_update_wrapper.dart';
import 'package:sk_live/core/widgets/global_patti_route_gate.dart';
import 'package:sk_live/core/widgets/global_win_broadcast_host.dart';
import 'package:sk_live/core/widgets/keep_screen_on_scope.dart';
import 'package:sk_live/core/widgets/maintenance_gate.dart';
import 'package:sk_live/core/widgets/minimized_room_overlay_host.dart';
import 'package:sk_live/core/widgets/room_bubble_lifecycle_host.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_world_banner.dart';
import 'package:sk_live/firebase_options.dart';
import 'package:sk_live/l10n/app_localizations.dart';
import 'package:sk_live/zone_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loaded only after the first frame. LiveKit, Hive, Firebase, and Supabase
/// stay out of the startup library graph until [mountAfterFirstPaint].
Widget buildApp() => const ProviderScope(child: SkLiveApp());

/// Local route decision, then the heavy services. The colored box is already
/// on screen. Nothing here is awaited by [main].
Future<void> mountAfterFirstPaint() async {
  WidgetsBinding.instance.addObserver(_MemoryPressureObserver());
  zoneErrorHandler = (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack);
    } catch (_) {
      debugPrint('Uncaught: $error\n$stack');
    }
  };

  await BootSession.instance.whenDecided();

  // The colored box is already on screen. Supabase assigns its client before
  // the first await inside initialize, then reads the keystore in the
  // background. Hive and the initial link start now so home can use them.
  // LiveKit / WebRTC and Firebase wait until the home/login frame is submitted.
  unawaited(_initSupabase());
  unawaited(_initLocalStores());
  unawaited(
    RoomDeepLinkService.captureInitialLink().timeout(
      const Duration(milliseconds: 800),
      onTimeout: () {
        debugPrint('[BOOTSTRAP] initial deep link timed out');
      },
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    unawaited(_initLiveKit());
    unawaited(_initVoiceAudio());
    unawaited(_initDeferredServices());
  });
}

Future<void> _initLiveKit() async {
  // Room audio was very quiet. WebRTC had never been initialised, so on Android
  // it created its audio device module with voice-communication attributes and
  // played every room through STREAM_VOICE_CALL — a stream whose level is
  // separate from media volume and low by default, and which the volume keys do
  // not raise outside a phone call. These attributes are read once when WebRTC
  // builds the audio device module, so this has to happen before any room is
  // joined. Listeners now play at media volume; the engine still switches the
  // session to communication mode while the microphone is publishing, so echo
  // cancellation is unaffected.
  try {
    await lk.LiveKitClient.initialize(
      initialAudioSessionOptions: const lk.AudioSessionOptions.mediaPlayback(),
    );
  } catch (e) {
    debugPrint('[voice] LiveKit initialize failed: $e');
  }
}

Future<void> _initLocalStores() async {
  try {
    await Hive.initFlutter();
    await HiveCacheService.init();
    debugPrint(
      '[HiveCache] boxes ready: app_ui, room_covers, user_media '
      '(rank_frames lazy)',
    );
  } catch (e) {
    debugPrint('[BOOTSTRAP] Hive init failed: $e');
  }
}

Future<void> _initSupabase() async {
  try {
    final projectHost = Uri.parse(
      AppConstants.supabaseUrl,
    ).host.split('.').first;
    final persistSessionKey = 'sb-$projectHost-auth-token';
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSupabaseLocalStorage(
          persistSessionKey: persistSessionKey,
        ),
      ),
    );
    debugPrint('[BOOTSTRAP] Supabase ready host=$projectHost (hardcoded Zuvo)');
  } catch (e) {
    debugPrint('[BOOTSTRAP] Supabase.initialize failed: $e');
  }
}

Future<void> _bootstrapFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppTelemetry.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _initVoiceAudio() async {
  try {
    await OrbitVoiceSessionService.initWebRtcAudioAttributes();
  } catch (e) {
    debugPrint('[BOOTSTRAP] voice audio init failed: $e');
  }
}

Future<void> _initDeferredServices() async {
  try {
    await BackgroundService.initializeService();
  } catch (e) {
    debugPrint('BackgroundService init failed: $e');
  }

  UpdateService.checkForUpdate();

  try {
    if (Firebase.apps.isEmpty) {
      await _bootstrapFirebase();
    }
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }
}

class SkLiveApp extends ConsumerWidget {
  const SkLiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(telemetryAuthSyncProvider);
    ref.watch(singleDeviceSessionGuardProvider);
    final router = ref.watch(AppRouter.routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'LIVO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: GlobalPattiRouteGate(
            child: RoomBubbleLifecycleHost(
              child: KeepScreenOnScope(
                child: MinimizedRoomOverlayHost(
                  child: LuckyBagWorldBroadcastHost(
                    child: GlobalWinBroadcastHost(
                      child: BigGiftPattiBroadcastHost(
                        child: DmGatewayHost(
                          child: MaintenanceGate(
                            child: ForceUpdateWrapper(
                              child: child ?? const SizedBox(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drops cached SVGA animations when the system reports memory pressure.
class _MemoryPressureObserver extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    SvgaCache.evictMemory();
    debugPrint('[memory] pressure — evicted cached SVGA animations');
  }
}
