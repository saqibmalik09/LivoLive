import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/core/providers/weekly_room_reward_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/features/auth/presentation/pages/account_management_screen.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_screen.dart';
import 'package:sk_live/features/auth/presentation/widgets/my_profile/my_profile_features_card.dart';
import 'package:sk_live/features/auth/presentation/widgets/my_profile/my_profile_header.dart';
import 'package:sk_live/features/auth/presentation/widgets/my_profile/my_profile_menu_card.dart';
import 'package:sk_live/features/auth/presentation/widgets/my_profile/my_profile_stats_row.dart';
import 'package:sk_live/features/chat/presentation/pages/feedback_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency_screen.dart';
import 'package:sk_live/features/home/presentation/pages/cp_nest_screen.dart';
import 'package:sk_live/features/home/presentation/pages/intimacy_list_screen.dart';
import 'package:sk_live/features/home/presentation/pages/host_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/profile_events_screen.dart';
import 'package:sk_live/features/home/presentation/pages/staff_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/bd/bd_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/bd/county_admin_center_screen.dart';
import 'package:sk_live/core/providers/mic_daily_reward_provider.dart';
import 'package:sk_live/core/l10n/app_locale.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/locale_provider.dart';
import 'package:sk_live/features/auth/presentation/pages/language_screen.dart';
import 'package:sk_live/features/auth/presentation/pages/blacklist_screen.dart';
import 'package:sk_live/features/home/presentation/pages/mic_reward_page.dart';
import 'package:sk_live/features/home/presentation/pages/room_reward_page.dart';
import 'package:sk_live/features/invite_earn/presentation/pages/invite_earn_screen.dart';
import 'package:sk_live/features/task/presentation/pages/task_screen.dart';
import 'package:sk_live/features/real_name/presentation/pages/real_name_guidelines_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  static const _pageBg = Color(0xFFF5F7FB);

  static const _heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFB074),
      Color(0xFFFF8A5C),
      Color(0xFFFF6BBA),
      Color(0xFFB56CFF),
      Color(0xFF5CCFE8),
      Color(0x99A8E4F5),
      _pageBg,
    ],
    stops: [0.0, 0.12, 0.32, 0.48, 0.62, 0.78, 1.0],
  );

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen>
    with WidgetsBindingObserver {
  bool _isAgencyOwner = false;
  bool _isAgencyAdmin = false;
  bool _isHost = false;
  bool _isStaff = false;
  String? _staffRoleLabel;
  String? _staffRole;
  bool _rolesInFlight = false;
  DateTime? _rolesCheckedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRoles());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRoles();
    }
  }

  Future<void> _checkRoles({bool force = false}) async {
    if (_rolesInFlight) return;
    if (!force &&
        _rolesCheckedAt != null &&
        DateTime.now().difference(_rolesCheckedAt!) <
            const Duration(minutes: 5)) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _rolesInFlight = true;
    final supabase = Supabase.instance.client;
    var isAgencyOwner = false;
    var isAgencyAdmin = false;
    var isHost = false;
    var isStaff = false;
    String? staffLabel;
    String? staffRole;

    try {
      final results = await Future.wait<dynamic>([
        StaffActions.getMyOwnedAgency().catchError((_) => null),
        supabase.rpc('get_my_agency_center').catchError((_) => null),
        supabase
            .from('agency_members')
            .select('id, role')
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle()
            .catchError((_) => null),
        supabase.rpc('get_my_staff_gate_info').catchError((_) => null),
      ]);

      final ownedAgency = results[0];
      isAgencyOwner = ownedAgency != null;

      final centerRaw = results[1];
      final center = centerRaw is Map
          ? Map<String, dynamic>.from(centerRaw)
          : <String, dynamic>{};
      if (center['success'] == true) {
        final accessRole = center['access_role']?.toString();
        if (accessRole == 'owner') {
          isAgencyOwner = true;
        } else if (accessRole == 'admin') {
          isAgencyAdmin = true;
        }
      }

      final host = results[2] as Map<String, dynamic>?;
      isHost = host != null || isAgencyOwner || isAgencyAdmin;
      if (!isAgencyAdmin && host?['role']?.toString() == 'admin') {
        isAgencyAdmin = true;
      }

      final gateRaw = results[3];
      final gate = gateRaw is Map
          ? Map<String, dynamic>.from(gateRaw)
          : <String, dynamic>{};
      final role = gate['staff_role']?.toString();
      if (role != null && role.isNotEmpty) {
        staffRole = role == 'bd_admin' ? 'county_admin' : role;
        isStaff =
            staffRole == 'super_bd' ||
            staffRole == 'county_admin' ||
            staffRole == 'bd';
        switch (staffRole) {
          case 'super_bd':
            staffLabel = 'Super Admin';
            break;
          case 'county_admin':
            staffLabel = 'County Admin';
            break;
          case 'bd':
            staffLabel = 'BD';
            break;
          case 'assistant':
            staffLabel = 'Assistant';
            break;
          case 'customer_service':
            staffLabel = 'Customer Service';
            break;
          default:
            staffLabel = role;
        }
      } else {
        try {
          final staffRows = await supabase
              .from('business_staff')
              .select('role')
              .eq('user_id', user.id)
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(1);
          if (staffRows.isNotEmpty) {
            final fallbackRole = staffRows.first['role']?.toString();
            staffRole = fallbackRole == 'bd_admin'
                ? 'county_admin'
                : fallbackRole;
            isStaff =
                staffRole == 'super_bd' ||
                staffRole == 'county_admin' ||
                staffRole == 'bd';
            switch (staffRole) {
              case 'super_bd':
                staffLabel = 'Super Admin';
                break;
              case 'county_admin':
                staffLabel = 'County Admin';
                break;
              case 'bd':
                staffLabel = 'BD';
                break;
              case 'assistant':
                staffLabel = 'Assistant';
                break;
              case 'customer_service':
                staffLabel = 'Customer Service';
                break;
            }
          }
        } catch (e2) {
          debugPrint('Error checking staff role: $e2');
        }
      }

      _rolesCheckedAt = DateTime.now();

      if (mounted) {
        setState(() {
          _isAgencyOwner = isAgencyOwner;
          _isAgencyAdmin = isAgencyAdmin;
          _isHost = isHost;
          _isStaff = isStaff;
          _staffRoleLabel = staffLabel;
          _staffRole = staffRole;
        });
        ref.invalidate(canAccessDiamondsProvider);
        ref.invalidate(myBusinessStaffProvider);
      }
    } catch (e) {
      debugPrint('Error checking roles: $e');
    } finally {
      _rolesInFlight = false;
    }
  }

  int? _ageFromBirth(dynamic dob) {
    if (dob == null) return null;
    final parsed = DateTime.tryParse(dob.toString());
    if (parsed == null) return null;
    final now = DateTime.now();
    var age = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }
    return age;
  }

  void _openLevelPicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Material(
          color: Theme.of(ctx).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconsax.medal_star),
                title: Text(context.l10n.profile_wealthCharmLevels),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRouter.userLevel);
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.building),
                title: Text(context.l10n.profile_agencyLevel),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRouter.userLevel, extra: {'tab': 'agency'});
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.home_hashtag),
                title: Text(context.l10n.profile_roomLevel),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRouter.roomLevel);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAgency() {
    final openCenter = _isAgencyOwner;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            openCenter ? const AgencyCenterScreen() : const AgencyScreen(),
      ),
    ).then((_) => _checkRoles(force: true));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (previous?.value?.session == null && next.value?.session != null) {
        _checkRoles(force: true);
      }
    });

    ref.listen(bottomNavIndexProvider, (previous, next) {
      final myIndex = bottomNavIndexForKey('my');
      if (previous != myIndex && next == myIndex) {
        _checkRoles();
      }
    });

    final userProfile = ref.watch(userProfileProvider).value;
    final statsAsync = ref.watch(currentUserStatsProvider);
    final mutualFriends = ref.watch(mutualFriendsProvider).valueOrNull ?? [];

    if (userProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userId = userProfile['id']?.toString() ?? '';
    final displayId =
        userProfile['short_id']?.toString() ??
        userId.substring(0, userId.length.clamp(0, 8)).toUpperCase();
    final vipLevel = (userProfile['vip_level'] as num?)?.toInt() ?? 0;
    final stats = statsAsync.value ?? {};
    final hostedRoomId = userId.isEmpty
        ? null
        : ref.watch(hostedRoomIdProvider(userId)).valueOrNull;

    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: MyProfileScreen._pageBg,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: kHomeTabScrollBottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: MyProfileScreen._heroGradient,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 28),
                    child: Column(
                      children: [
                        MyProfileHeader(
                          username: userProfile['username'] ?? 'User',
                          avatarUrl: userProfile['avatar_url'],
                          displayId: displayId,
                          userId: userId,
                          specialIdLevel:
                              (userProfile['special_id_level'] as num?)
                                  ?.toInt(),
                          gender: userProfile['gender']?.toString(),
                          countryCode: userProfile['country_code']?.toString(),
                          age: _ageFromBirth(userProfile['date_of_birth']),
                          lightTheme: true,
                          onAvatarTap: () => context.push(
                            AppRouter.userProfile,
                            extra: userId,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MyProfileStatsRow(
                          followers: stats['followers'] as int? ?? 0,
                          following: stats['following'] as int? ?? 0,
                          friends: mutualFriends.length,
                          visits: (stats['visits'] as num?)?.toInt() ?? 0,
                          lightTheme: true,
                          onVisitsTap: () => context.push(
                            AppRouter.profileVisitors,
                            extra: {'userId': userId},
                          ),
                          onFollowersTap: () => context.push(
                            AppRouter.socialDetail,
                            extra: {'userId': userId, 'tab': 1},
                          ),
                          onFollowingTap: () => context.push(
                            AppRouter.socialDetail,
                            extra: {'userId': userId, 'tab': 0},
                          ),
                          onFriendsTap: () {
                            ref.read(bottomNavIndexProvider.notifier).state =
                                bottomNavIndexForKey('message');
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: topInset + 8,
                    right: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push(AppRouter.editProfile),
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Iconsax.edit_2,
                            size: 22,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MyProfileFeaturesCard(
                      vipLevel: vipLevel,
                      showHostCenter: _isHost,
                      showWeeklyRoomReward:
                          hostedRoomId != null && hostedRoomId.isNotEmpty,
                      onJoinVip: () => context.push(AppRouter.vipCenter),
                      onWallet: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      ),
                      onStore: () => context.push(AppRouter.shop),
                      onVip: () => context.push(AppRouter.vipCenter),
                      onDecoration: () => context.push(
                        AppRouter.inventory,
                        extra: {'userId': userId, 'tab': 'frames'},
                      ),
                      onAgency: _openAgency,
                      onEvents: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEventsScreen(),
                        ),
                      ),
                      onHostCenter: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HostCenterScreen(),
                          ),
                        );
                        _checkRoles();
                      },
                      onWeeklyRoomReward: () {
                        final roomId = hostedRoomId;
                        if (roomId == null || roomId.isEmpty) return;
                        ref.invalidate(
                          weeklyRoomRewardProgressProvider(roomId),
                        );
                        RoomRewardPage.open(context, roomId: roomId);
                      },
                      onMicReward: () {
                        ref.invalidate(micDailyRewardProgressProvider);
                        MicRewardPage.open(context);
                      },
                    ),
                    if (_isStaff) ...[
                      const SizedBox(height: 12),
                      MyProfileStandaloneMenuTile(
                        icon: Iconsax.hierarchy,
                        label: context.l10n.profile_staffCenter(
                          _staffRoleLabel ?? context.l10n.profile_roleStaff,
                        ),
                        onTap: () async {
                          final Widget page;
                          switch (_staffRole) {
                            case 'bd':
                              page = const BdCenterScreen();
                              break;
                            case 'county_admin':
                              page = const CountyAdminCenterScreen();
                              break;
                            default:
                              page = const StaffCenterScreen();
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => page),
                          );
                          _checkRoles();
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    MyProfileMenuCard(
                      items: [
                        MyProfileMenuItem(
                          icon: Iconsax.people,
                          label: context.l10n.profile_inviteFriend,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InviteEarnScreen(inviteCode: displayId),
                              ),
                            );
                          },
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.shield_tick,
                          label: context.l10n.profile_realNameVerify,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RealNameGuidelinesScreen(),
                            ),
                          ),
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.task_square,
                          label: context.l10n.profile_task,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TaskScreen(),
                            ),
                          ),
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.medal_star,
                          label: context.l10n.profile_level,
                          onTap: _openLevelPicker,
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.heart,
                          label: context.l10n.profile_cpNest,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CPNestScreen(),
                            ),
                          ),
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.user_add,
                          label: context.l10n.profile_buddies,
                          onTap: () {
                            if (userId.isEmpty) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    IntimacyListScreen(userId: userId),
                              ),
                            );
                          },
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.slash,
                          label: context.l10n.profile_blacklist,
                          onTap: () => BlacklistScreen.open(
                            context,
                            hostedRoomId: hostedRoomId,
                          ),
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.message_question,
                          label: context.l10n.profile_feedback,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FeedbackScreen(),
                            ),
                          ),
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.global,
                          label: context.l10n.profile_language,
                          subtitle: _currentLanguageLabel(context),
                          onTap: () => LanguageScreen.open(context),
                        ),
                        MyProfileMenuItem(
                          icon: Iconsax.setting_2,
                          label: context.l10n.profile_settings,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountManagementScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (userProfile['is_reseller'] == true) ...[
                      const SizedBox(height: 12),
                      MyProfileStandaloneMenuTile(
                        icon: Iconsax.security_user,
                        label: context.l10n.profile_resellerPanel,
                        onTap: () => context.push(AppRouter.reseller),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _currentLanguageLabel(BuildContext context) {
    final code = ref.watch(localeProvider).languageCode;
    final l = context.l10n;
    switch (code) {
      case 'en':
        return l.lang_english;
      case 'ar':
        return l.lang_arabic;
      case 'id':
        return l.lang_indonesian;
      case 'tr':
        return l.lang_turkish;
      case 'ur':
        return l.lang_urdu;
      case 'hi':
        return l.lang_hindi;
      case 'pt':
        return l.lang_portuguese;
      case 'th':
        return l.lang_thai;
      case 'vi':
        return l.lang_vietnamese;
      default:
        return AppLocale.defaultCode;
    }
  }
}
