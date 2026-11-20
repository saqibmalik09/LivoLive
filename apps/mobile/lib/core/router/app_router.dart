import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/onboarding/presentation/pages/splash_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/email_login_screen.dart';
import '../../features/auth/presentation/pages/email_password_login_screen.dart';
import '../../features/auth/presentation/pages/id_login_screen.dart';
import '../../features/auth/presentation/pages/otp_screen.dart';
import '../auth/boot_session.dart';
import '../providers/auth_provider.dart';
import '../providers/device_ban_provider.dart';
import '../../features/auth/presentation/pages/profile_setup_screen.dart';
import '../../features/auth/presentation/pages/account_banned_screen.dart';
import '../../features/home/presentation/pages/main_screen.dart';
import '../../features/home/presentation/pages/create_post_screen.dart';
import '../../features/home/presentation/pages/post_detail_screen.dart';
import '../../features/home/presentation/pages/user_moments_detail_screen.dart';
import '../../features/home/presentation/pages/all_topics_screen.dart';
import '../../features/home/presentation/pages/topic_posts_screen.dart';
import '../../features/chat/presentation/pages/chat_screen.dart';
import '../../features/chat/presentation/pages/messages_screen.dart';
import '../../features/auth/presentation/pages/vip_center_screen.dart';
import '../../features/auth/presentation/pages/user_level_screen.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';
import '../../features/home/presentation/pages/shop_screen.dart';
import '../../features/auth/presentation/pages/social_detail_screen.dart';
import '../../features/auth/presentation/pages/profile_visitors_screen.dart';
import '../../features/auth/presentation/pages/edit_profile_screen.dart';
import '../../features/auth/presentation/pages/user_profile_screen.dart';
import '../../features/auth/presentation/pages/inventory_screen.dart';
import '../../features/auth/presentation/pages/cp_level_screen.dart';
import '../../features/auth/presentation/pages/room_level_screen.dart';
import '../../features/auth/presentation/pages/reseller_screen.dart';
import '../../features/merchant/presentation/pages/merchant_screen.dart';
import '../../features/home/presentation/pages/room_deep_link_screen.dart';
import 'package:sk_live/core/services/room_deep_link_service.dart';
import 'package:sk_live/core/router/room_route_observer.dart';
import 'package:sk_live/core/router/telemetry_route_observer.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String login = '/login';
  static const String emailLogin = '/login/email';
  static const String emailPasswordLogin = '/login/email/password';
  static const String idLogin = '/login/id';
  static const String otp = '/otp';
  static const String profileSetup = '/profile-setup';
  static const String banned = '/banned';
  static const String home = '/home';
  static const String createPost = '/create-post';
  static const String postDetail = '/post-detail';

  static bool suppressGlobalPattiOverlays(String matchedLocation) {
    if (matchedLocation == splash) return true;
    if (matchedLocation == login || matchedLocation.startsWith('$login/')) {
      return true;
    }
    if (matchedLocation == otp) return true;
    if (matchedLocation == profileSetup) return true;
    if (matchedLocation == banned) return true;
    return false;
  }

  static const String userMoments = '/user-moments';
  static const String allTopics = '/all-topics';
  static const String topicPosts = '/topic-posts';
  static const String chat = '/chat';
  static const String messages = '/messages';
  static const String vipCenter = '/vip-center';
  static const String userLevel = '/user-level';
  static const String wealthLevel = '/wealth-level';
  static const String charmLevel = '/charm-level';
  static const String shop = '/shop';
  static const String socialDetail = '/social-detail';
  static const String profileVisitors = '/profile-visitors';
  static const String userProfile = '/user-profile';
  static const String editProfile = '/edit-profile';
  static const String inventory = '/inventory';
  static const String cpLevel = '/cp-level';
  static const String roomLevel = '/room-level';
  static const String roomDeepLink = '/room';
  static const String reseller = '/reseller';
  static const String merchant = '/merchant';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final routerProvider = Provider<GoRouter>((ref) {
    final notifier = _RouterNotifier(ref);

    final router = GoRouter(
      navigatorKey: navigatorKey,
      observers: [roomRouteObserver, telemetryRouteObserver],
      // Chosen after the first frame from the local session. Splash is only
      // the fallback when that probe has not reported yet.
      initialLocation: switch (BootSession.instance.destination) {
        BootDestination.home => home,
        BootDestination.login => login,
        null => splash,
      },
      refreshListenable: notifier,
      redirect: (context, state) {
        final authAsync = ref.read(authStateProvider);
        final profileState = ref.read(userProfileProvider);
        final deviceBanState = ref.read(deviceBanProvider);

        Session? clientSession;
        try {
          if (Supabase.instance.isInitialized) {
            clientSession = Supabase.instance.client.auth.currentSession;
          }
        } catch (e) {
          debugPrint('[BOOT] supabase session unavailable: $e');
        }
        final streamSession = authAsync.asData?.value.session;
        final session = clientSession ?? streamSession;
        final loggedIn = session != null;
        final profile = profileState.valueOrNull;
        final deviceBanned = deviceBanState.valueOrNull?.isBanned == true;
        final accountBanned = profile?['is_banned'] == true;

        final isSplash = state.matchedLocation == splash;
        final isLoginFlow =
            state.matchedLocation == login ||
            state.matchedLocation.startsWith('$login/');
        final isOtp = state.matchedLocation == otp;
        final isSetup = state.matchedLocation == profileSetup;
        final isBannedRoute = state.matchedLocation == banned;
        final isRoomDeepLink = state.matchedLocation.startsWith(
          '$roomDeepLink/',
        );

        final roomIdFromPath = state.pathParameters['roomId'];
        if (!loggedIn &&
            isRoomDeepLink &&
            roomIdFromPath != null &&
            roomIdFromPath.isNotEmpty) {
          RoomDeepLinkService.setPending(roomIdFromPath);
        }

        if (loggedIn &&
            deviceBanState.isLoading &&
            !deviceBanState.hasValue &&
            !isSplash &&
            !isBannedRoute) {
          return null;
        }

        if (deviceBanned || (loggedIn && accountBanned)) {
          if (!isBannedRoute) return banned;
          return null;
        }
        if (isBannedRoute) {
          return loggedIn ? home : login;
        }

        // Splash leaves from the local probe only. Auth loading, token
        // refresh, and the signed-out recovery retries must not hold `/`.
        if (isSplash) {
          final boot = BootSession.instance.destination;
          if (boot == null) return null;
          if (boot == BootDestination.login && !loggedIn) return login;
          return home;
        }

        if (!loggedIn) {
          if (authAsync.isLoading || authAsync.hasError) return null;
          if (ref.read(authRecoveryInProgressProvider)) return null;
          if (ref.read(currentLiveRoomIdProvider) != null) return null;
          if (!isSplash && !isLoginFlow && !isOtp) return login;
          return null;
        }

        if (loggedIn) {
          if (profileState.isLoading && profile == null) return null;

          final gender = profile?['gender']?.toString().trim();
          final country = profile?['country_code']?.toString().trim();
          final looksLikeDbRow =
              profile != null &&
              (profile.containsKey('created_at') ||
                  profile.containsKey('username') ||
                  profile.containsKey('public_id') ||
                  profile.containsKey('phone') ||
                  profile.containsKey('email'));
          final isIncomplete =
              looksLikeDbRow &&
              ((gender == null || gender.isEmpty) ||
                  (country == null || country.isEmpty));
          if (isIncomplete) {
            if (!isSetup) return profileSetup;
            return null;
          }
          if (profile == null) return null;

          final pendingRoomId = RoomDeepLinkService.consumePending();
          if (pendingRoomId != null && !isRoomDeepLink) {
            return '$roomDeepLink/$pendingRoomId';
          }

          if (isLoginFlow || isOtp || isSplash || isSetup) return home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: emailLogin,
          builder: (context, state) => const EmailLoginScreen(),
        ),
        GoRoute(
          path: emailPasswordLogin,
          builder: (context, state) {
            final email = state.extra as String? ?? '';
            return EmailPasswordLoginScreen(email: email);
          },
        ),
        GoRoute(
          path: idLogin,
          builder: (context, state) => const IdLoginScreen(),
        ),
        GoRoute(
          path: otp,
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return OtpScreen(phoneNumber: phone);
          },
        ),
        GoRoute(
          path: profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: banned,
          builder: (context, state) => const AccountBannedScreen(),
        ),
        GoRoute(path: home, builder: (context, state) => const MainScreen()),
        GoRoute(
          path: createPost,
          builder: (context, state) => const CreatePostScreen(),
        ),
        GoRoute(
          path: postDetail,
          builder: (context, state) {
            final post = state.extra as Map<String, dynamic>;
            return PostDetailScreen(post: post);
          },
        ),
        GoRoute(
          path: AppRouter.userMoments,
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            return UserMomentsDetailScreen(
              userId: data['user_id'],
              username: data['username'],
              avatarUrl: data['avatar_url'],
              posts: data['posts'],
            );
          },
        ),
        GoRoute(
          path: AppRouter.allTopics,
          builder: (context, state) => const AllTopicsScreen(),
        ),
        GoRoute(
          path: AppRouter.topicPosts,
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            return TopicPostsScreen(
              topicId: data['topicId'],
              topicName: data['topicName'],
            );
          },
        ),
        GoRoute(
          path: AppRouter.chat,
          builder: (context, state) {
            final data = state.extra as Map<String, dynamic>;
            return ChatScreen(
              conversationId: data['conversationId'],
              targetUserId: data['targetUserId'],
              targetUsername: data['targetUsername'],
              targetAvatar: data['targetAvatar'],
            );
          },
        ),
        GoRoute(
          path: AppRouter.messages,
          builder: (context, state) => const MessagesScreen(),
        ),
        GoRoute(
          path: vipCenter,
          builder: (context, state) => const VipCenterScreen(),
        ),
        GoRoute(
          path: userLevel,
          builder: (context, state) {
            final extra = state.extra;
            final tab = extra is Map
                ? extra['tab']?.toString()
                : extra?.toString();
            final initialTab = tab == 'charm'
                ? UserLevelKind.charm
                : tab == 'agency'
                ? UserLevelKind.agency
                : UserLevelKind.wealth;
            return UserLevelScreen(initialTab: initialTab);
          },
        ),
        GoRoute(
          path: wealthLevel,
          builder: (context, state) =>
              const UserLevelScreen(initialTab: UserLevelKind.wealth),
        ),
        GoRoute(
          path: charmLevel,
          builder: (context, state) =>
              const UserLevelScreen(initialTab: UserLevelKind.charm),
        ),
        GoRoute(path: shop, builder: (context, state) => const ShopScreen()),
        GoRoute(
          path: socialDetail,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return SocialDetailScreen(
              userId: extra['userId'],
              initialTabIndex: extra['tab'] ?? 0,
            );
          },
        ),
        GoRoute(
          path: profileVisitors,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            final userId = extra['userId']?.toString() ?? '';
            return ProfileVisitorsScreen(profileId: userId);
          },
        ),
        GoRoute(
          path: userProfile,
          builder: (context, state) {
            final userId = state.extra as String;
            return UserProfileScreen(userId: userId);
          },
        ),
        GoRoute(
          path: editProfile,
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: inventory,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return InventoryScreen(
              userId: extra['userId'],
              initialTab: extra['tab'] ?? 'frames',
            );
          },
        ),
        GoRoute(
          path: cpLevel,
          builder: (context, state) => const CPLevelScreen(),
        ),
        GoRoute(
          path: roomLevel,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return RoomLevelScreen(roomId: extra['roomId']);
          },
        ),
        GoRoute(
          path: reseller,
          builder: (context, state) {
            final extra = state.extra;
            var tab = 0;
            if (extra is Map) {
              final t = extra['tab']?.toString();
              if (t == 'bills') tab = 1;
              if (t == 'history') tab = 2;
              final n = extra['initialTab'];
              if (n is int) tab = n.clamp(0, 2);
            }
            return ResellerScreen(initialTab: tab);
          },
        ),
        GoRoute(
          path: merchant,
          builder: (context, state) {
            final extra = state.extra;
            var tab = 0;
            if (extra is Map) {
              final t = extra['tab']?.toString();
              if (t == 'recharge') tab = 1;
              if (t == 'sellers') tab = 2;
              if (t == 'history') tab = 3;
              final n = extra['initialTab'];
              if (n is int) tab = n.clamp(0, 3);
            }
            return MerchantScreen(initialTab: tab);
          },
        ),
        GoRoute(
          path: '$roomDeepLink/:roomId',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId'] ?? '';
            return RoomDeepLinkScreen(roomId: roomId);
          },
        ),
      ],
    );

    RoomDeepLinkService.listen((roomId) {
      router.go('$roomDeepLink/$roomId');
    });

    ref.onDispose(() {
      router.dispose();
      notifier.dispose();
    });

    return router;
  });
}

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  int _lastSessionExpiredTick = 0;

  @override
  void dispose() {
    BootSession.instance.removeListener(notifyListeners);
    super.dispose();
  }

  _RouterNotifier(this._ref) {
    BootSession.instance.addListener(notifyListeners);
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(deviceBanProvider, (_, __) => notifyListeners());
    _ref.listen(authRecoveryInProgressProvider, (_, __) => notifyListeners());
    _ref.listen(currentLiveRoomIdProvider, (_, __) => notifyListeners());
    _ref.listen(authSessionExpiredTickProvider, (_, tick) {
      if (tick > _lastSessionExpiredTick) {
        _lastSessionExpiredTick = tick;
        clearActiveRoomState(_ref);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = AppRouter.navigatorKey.currentContext;
          if (ctx == null) return;
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
            const SnackBar(
              content: Text('Session expired, please log in again.'),
            ),
          );
        });
        notifyListeners();
      }
    });
    _ref.listen(userProfileProvider, (prev, next) {
      if (next.hasValue && !next.isLoading) {
        notifyListeners();
      }
    });
  }
}
