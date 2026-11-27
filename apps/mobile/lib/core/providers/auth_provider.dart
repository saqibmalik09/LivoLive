import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/auth/secure_supabase_local_storage.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/providers/device_ban_provider.dart';
import 'package:sk_live/core/services/app_telemetry.dart';
import 'package:sk_live/core/services/auth_service.dart';

final authRecoveryInProgressProvider = StateProvider<bool>((ref) => false);

final authSessionExpiredTickProvider = StateProvider<int>((ref) => 0);

final authStateProvider = StreamProvider<AuthState>((ref) async* {
  final auth = AuthService.instance;
  final initial = auth.currentSession;
  if (initial != null) {
    yield AuthState(AuthChangeEvent.initialSession, initial);
  }

  await for (final event in auth.authStateChanges.handleError((
    Object e,
    StackTrace st,
  ) {
    debugPrint('[Auth] onAuthStateChange error ignored: $e');
  })) {
    if (event.event == AuthChangeEvent.signedOut) {
      if (auth.isUserInitiatedSignOut) {
        auth.clearUserInitiatedSignOut();
        ref.read(authRecoveryInProgressProvider.notifier).state = false;
        yield event;
        continue;
      }

      ref.read(authRecoveryInProgressProvider.notifier).state = true;
      final restored = await _tryRecoverSession(auth);
      ref.read(authRecoveryInProgressProvider.notifier).state = false;

      if (restored != null) {
        debugPrint('[Auth] recovered session after spurious signedOut');
        yield AuthState(AuthChangeEvent.tokenRefreshed, restored);
        continue;
      }

      debugPrint('[Auth] recovery failed — confirmed signedOut');
      ref.read(authSessionExpiredTickProvider.notifier).state++;
      yield event;
      continue;
    }

    yield event;
  }
});

Future<Session?> _tryRecoverSession(AuthService auth) async {
  // One immediate read. Sleeping 400+900+1600ms here used to run while the
  // router refused to leave `/`.
  try {
    if (auth.currentSession != null) return auth.currentSession;

    final storage = SecureSupabaseLocalStorage.instance;
    final json =
        await storage?.readSessionBackup() ?? await storage?.accessToken();
    if (json == null || json.isEmpty) {
      debugPrint('[Auth] recover: no backup session');
      return null;
    }

    final response = await Supabase.instance.client.auth.recoverSession(json);
    return response.session ?? auth.currentSession;
  } catch (e) {
    debugPrint('[Auth] recover failed: $e');
    return auth.currentSession;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService.instance;
});

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final userId = ref.watch(
    authStateProvider.select((a) => a.value?.session?.user.id),
  );
  final sessionUserId = userId ?? AuthService.instance.currentSession?.user.id;
  if (sessionUserId == null) {
    return Stream.value(null);
  }

  final client = Supabase.instance.client;

  return _userProfileUpdates(client, sessionUserId);
});

const _profileFetchTimeout = Duration(seconds: 2);
const _firstProfileFetchTimeout = Duration(seconds: 10);

Map<String, dynamic>? _cachedUserProfile(String sessionUserId) {
  final cachedMedia = HiveCacheService.loadProfileMedia(sessionUserId);
  final cachedGender = cachedMedia?['gender']?.trim();
  final cachedCountry = cachedMedia?['country_code']?.trim();
  if (cachedGender == null ||
      cachedGender.isEmpty ||
      cachedCountry == null ||
      cachedCountry.isEmpty) {
    return null;
  }
  return {
    'id': sessionUserId,
    'avatar_url': cachedMedia?['avatar_url'],
    'banner_url': cachedMedia?['banner_url'],
    'gender': cachedGender,
    'country_code': cachedCountry,
  };
}

Stream<Map<String, dynamic>?> _userProfileUpdates(
  SupabaseClient client,
  String sessionUserId,
) async* {
  final cached = _cachedUserProfile(sessionUserId);
  if (cached != null) yield cached;

  yield* realtimeWithFallback<Map<String, dynamic>?>(
    fetch: () async {
      try {
        // With nothing cached (first login on a new install) the router waits
        // on this row to leave the login screen, and that first request also
        // pays for the connection setup. Two seconds was not enough for it.
        final hasLocal = _cachedUserProfile(sessionUserId) != null;
        final row = await client
            .from('users')
            .select()
            .eq('id', sessionUserId)
            .maybeSingle()
            .timeout(hasLocal ? _profileFetchTimeout : _firstProfileFetchTimeout);
        if (row != null) {
          final profile = Map<String, dynamic>.from(row);
          await HiveCacheService.saveProfileMedia(
            sessionUserId,
            avatarUrl: profile['avatar_url']?.toString(),
            bannerUrl: profile['banner_url']?.toString(),
            gender: profile['gender']?.toString(),
            countryCode: profile['country_code']?.toString(),
          );
          return profile;
        }
        return null;
      } catch (e) {
        debugPrint('[userProfileProvider] fetch failed: $e');
        final cached = _cachedUserProfile(sessionUserId);
        if (cached != null) return cached;
        // No local profile. Let the realtime subscription deliver the row
        // instead of completing the stream with null.
        rethrow;
      }
    },
    realtime: () async* {
      Map<String, dynamic>? last;
      await for (final rows
          in client
              .from('users')
              .stream(primaryKey: ['id'])
              .eq('id', sessionUserId)) {
        if (rows.isEmpty) {
          if (last != null) yield last;
          continue;
        }
        last = Map<String, dynamic>.from(rows.first);
        await HiveCacheService.saveProfileMedia(
          sessionUserId,
          avatarUrl: last['avatar_url']?.toString(),
          bannerUrl: last['banner_url']?.toString(),
          gender: last['gender']?.toString(),
          countryCode: last['country_code']?.toString(),
        );
        yield last;
      }
    },
  );
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref.watch(authServiceProvider), ref);
    });

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;
  final Ref _ref;
  AuthController(this._authService, this._ref)
    : super(const AsyncValue.data(null));

  Future<void> _afterAuthSuccess() async {
    try {
      await _ref.read(deviceBanProvider.notifier).registerNow();
    } catch (_) {}
  }

  Future<bool> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithOtp(phone);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String token) async {
    state = const AsyncValue.loading();
    try {
      await _authService.verifyOtp(phone, token);
      await _afterAuthSuccess();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// The router only leaves the login screen once the profile row is loaded.
  /// Holding the spinner until then stops a slow first load looking like a
  /// login that silently failed.
  Future<void> _waitForProfile() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (mounted && DateTime.now().isBefore(deadline)) {
      if (_ref.read(userProfileProvider).valueOrNull != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await AuthService.instance.signInWithGoogle();
      await _afterAuthSuccess();
      await _waitForProfile();
      if (!mounted) return true;
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> signInWithFacebook() async {
    state = const AsyncLoading();
    try {
      await AuthService.instance.signInWithFacebook();
      await _afterAuthSuccess();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      await _afterAuthSuccess();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<({bool success, bool needsEmailConfirmation})> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
      );
      if (response.session != null) {
        await _afterAuthSuccess();
      }
      state = const AsyncValue.data(null);
      if (response.session != null) {
        return (success: true, needsEmailConfirmation: false);
      }
      if (response.user != null) {
        return (success: true, needsEmailConfirmation: true);
      }
      return (success: false, needsEmailConfirmation: false);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return (success: false, needsEmailConfirmation: false);
    }
  }

  Future<bool> updateProfile({
    required String gender,
    required String countryCode,
    required String username,
  }) async {
    state = const AsyncLoading();
    try {
      await _authService.updateProfile(
        gender: gender,
        countryCode: countryCode,
        username: username,
      );
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      debugPrint('AuthController Error in updateProfile: $e');
      state = AsyncError(e, stack);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    final userId =
        _authService.currentSession?.user.id ??
        Supabase.instance.client.auth.currentUser?.id;
    clearActiveRoomState(_ref);
    await _authService.signOut();
    if (userId != null && userId.isNotEmpty) {
      await HiveCacheService.clearUserMedia(userId);
    }
    await AppTelemetry.clearUser();
    _ref.invalidate(userProfileProvider);
    state = const AsyncValue.data(null);
  }
}
