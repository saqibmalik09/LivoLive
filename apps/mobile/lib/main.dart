import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sk_live/l10n/app_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/auth/secure_supabase_local_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sk_live/firebase_options.dart';
import 'core/services/app_telemetry.dart';
import 'core/services/notification_service.dart';
import 'core/services/orbit_voice_session_service.dart';
import 'core/services/update_service.dart';
import 'core/services/background_service.dart';
import 'core/services/hive_cache_service.dart';
import 'core/util/app_constants.dart';
import 'core/providers/telemetry_auth_sync.dart';
import 'core/providers/single_device_session_guard.dart';
import 'core/widgets/force_update_wrapper.dart';
import 'core/widgets/maintenance_gate.dart';
import 'core/widgets/global_patti_route_gate.dart';
import 'core/widgets/global_win_broadcast_host.dart';
import 'core/widgets/big_gift_patti_broadcast_host.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_world_banner.dart';
import 'core/widgets/minimized_room_overlay_host.dart';
import 'core/widgets/keep_screen_on_scope.dart';
import 'core/widgets/room_bubble_lifecycle_host.dart';
import 'core/widgets/room_floating_bubble_overlay.dart';
import 'core/widgets/dm_gateway_host.dart';
import 'core/services/room_deep_link_service.dart';
import 'core/l10n/app_locale.dart';
import 'core/providers/locale_provider.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  overlayMainEntry();
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  await Hive.initFlutter();
  await HiveCacheService.init();
  debugPrint(
    '[HiveCache] boxes ready: app_ui, room_covers, user_media '
    '(rank_frames lazy)',
  );

  try {
    await _bootstrapFirebase();
  } catch (e, st) {
    debugPrint('Firebase bootstrap failed: $e\n$st');
  }

  final projectHost = Uri.parse(AppConstants.supabaseUrl).host.split('.').first;
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

  await RoomDeepLinkService.captureInitialLink();

  await OrbitVoiceSessionService.initWebRtcAudioAttributes();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runZonedGuarded(() => runApp(const ProviderScope(child: SkLiveApp())), (
    error,
    stack,
  ) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack);
    } catch (_) {
      debugPrint('Uncaught: $error\n$stack');
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initDeferredServices());
  });
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
