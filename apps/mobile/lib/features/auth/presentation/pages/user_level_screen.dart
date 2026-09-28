import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/agency_ranking_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/level_config_provider.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_badge_table.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_how_to_upgrade.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_info_card.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_reward_grid.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_screen_theme.dart';
import 'package:sk_live/features/auth/presentation/widgets/level/level_user_progress_card.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

const _kProgressCardOverlap = 96.0;

int _tabIndexForKind(UserLevelKind kind) {
  switch (kind) {
    case UserLevelKind.wealth:
      return 0;
    case UserLevelKind.charm:
      return 1;
    case UserLevelKind.agency:
      return 2;
  }
}

UserLevelKind _kindForTabIndex(int index) {
  switch (index) {
    case 1:
      return UserLevelKind.charm;
    case 2:
      return UserLevelKind.agency;
    default:
      return UserLevelKind.wealth;
  }
}

class UserLevelScreen extends ConsumerStatefulWidget {
  const UserLevelScreen({super.key, this.initialTab = UserLevelKind.wealth});

  final UserLevelKind initialTab;

  @override
  ConsumerState<UserLevelScreen> createState() => _UserLevelScreenState();
}

class _UserLevelScreenState extends ConsumerState<UserLevelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _tabIndexForKind(widget.initialTab),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh(UserLevelKind kind) async {
    if (kind == UserLevelKind.wealth) {
      ref.invalidate(wealthLevelConfigsProvider);
      await ref.read(wealthLevelConfigsProvider.future);
    } else if (kind == UserLevelKind.charm) {
      ref.invalidate(charmLevelConfigsProvider);
      await ref.read(charmLevelConfigsProvider.future);
    } else {
      ref.invalidate(agencyLevelConfigsProvider);
      ref.invalidate(agencyOwnerExpProvider);
      ref.invalidate(myAgencyProvider);
      await ref.read(agencyLevelConfigsProvider.future);
      await ref.read(agencyOwnerExpProvider.future);
    }
    ref.invalidate(userProfileProvider);
    await ref.read(userProfileProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final activeKind = _kindForTabIndex(_tabController.index);
    final activeTheme = LevelScreenTheme.forKind(activeKind);
    final heroHeight = MediaQuery.sizeOf(context).height * 0.38;

    return Scaffold(
      backgroundColor: activeTheme.backgroundColor,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Image.asset(
                        activeTheme.headerBackgroundAsset,
                        key: ValueKey(activeTheme.headerBackgroundAsset),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: heroHeight,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: activeTheme.backgroundColor,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: activeTheme.headerGradient,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: heroHeight * 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              activeTheme.backgroundColor.withValues(
                                alpha: 0.2,
                              ),
                              activeTheme.backgroundColor.withValues(
                                alpha: 0.85,
                              ),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          TabBar(
                            controller: _tabController,
                            indicatorColor: activeTheme.accentColor,
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white54,
                            onTap: (_) => setState(() {}),
                            tabs: const [
                              Tab(text: 'Wealth'),
                              Tab(text: 'Charm'),
                              Tab(text: 'Agency'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: activeTheme.backgroundColor,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _LevelTabBody(
                        kind: UserLevelKind.wealth,
                        onRefresh: () => _refresh(UserLevelKind.wealth),
                      ),
                      _LevelTabBody(
                        kind: UserLevelKind.charm,
                        onRefresh: () => _refresh(UserLevelKind.charm),
                      ),
                      _LevelTabBody(
                        kind: UserLevelKind.agency,
                        onRefresh: () => _refresh(UserLevelKind.agency),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: heroHeight - _kProgressCardOverlap,
            left: 0,
            right: 0,
            child: _LevelProgressCardOverlay(kind: activeKind),
          ),
        ],
      ),
    );
  }
}

class _LevelProgressCardOverlay extends ConsumerWidget {
  const _LevelProgressCardOverlay({required this.kind});

  final UserLevelKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = LevelScreenTheme.forKind(kind);

    if (kind == UserLevelKind.agency) {
      final configsAsync = ref.watch(agencyLevelConfigsProvider);
      final agencyAsync = ref.watch(myAgencyProvider);
      final expAsync = ref.watch(agencyOwnerExpProvider);
      final userAsync = ref.watch(userProfileProvider);

      return configsAsync.when(
        loading: () => const SizedBox(height: _kProgressCardOverlap),
        error: (_, __) => const SizedBox.shrink(),
        data: (configs) {
          return agencyAsync.when(
            loading: () => const SizedBox(height: _kProgressCardOverlap),
            error: (_, __) => const SizedBox.shrink(),
            data: (agency) {
              if (agency == null || configs.isEmpty) {
                return const SizedBox(height: _kProgressCardOverlap);
              }

              return expAsync.when(
                loading: () => const SizedBox(height: _kProgressCardOverlap),
                error: (_, __) => const SizedBox.shrink(),
                data: (currentValue) {
                  return userAsync.when(
                    loading: () =>
                        const SizedBox(height: _kProgressCardOverlap),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (user) {
                      final currentLevel = agencyLevelFromExp(
                        configs,
                        currentValue,
                      );
                      final window = levelWindow(configs, currentLevel);
                      final prevExp = window.prev?['min_exp'] as num? ?? 0;
                      final nextConfig = window.next;
                      final nextLevel =
                          (nextConfig?['level'] as num?)?.toInt() ??
                          (currentLevel + 1);
                      final nextExp =
                          nextConfig?['min_exp'] as num? ??
                          (currentValue + 1000);
                      final expToNext = nextExp - currentValue;
                      final progress = calculateLevelProgress(
                        currentValue,
                        prevExp,
                        nextExp,
                      );

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: LevelUserProgressCard(
                          key: const ValueKey(UserLevelKind.agency),
                          theme: theme,
                          username: agency['name']?.toString() ?? 'My Agency',
                          avatarUrl: user?['avatar_url']?.toString(),
                          currentLevel: currentLevel,
                          nextLevel: nextLevel,
                          currentValue: currentValue,
                          expToNext: expToNext,
                          progress: progress,
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    final userAsync = ref.watch(userProfileProvider);
    final configsAsync = kind == UserLevelKind.wealth
        ? ref.watch(wealthLevelConfigsProvider)
        : ref.watch(charmLevelConfigsProvider);

    return configsAsync.when(
      loading: () => const SizedBox(height: _kProgressCardOverlap),
      error: (_, __) => const SizedBox.shrink(),
      data: (configs) {
        return userAsync.when(
          loading: () => const SizedBox(height: _kProgressCardOverlap),
          error: (_, __) => const SizedBox.shrink(),
          data: (user) {
            if (user == null || configs.isEmpty) {
              return const SizedBox(height: _kProgressCardOverlap);
            }

            final currentLevel = kind == UserLevelKind.wealth
                ? (user['wealth_level'] as num?)?.toInt() ?? 0
                : (user['charm_level'] as num?)?.toInt() ?? 1;
            final currentValue = kind == UserLevelKind.wealth
                ? user['wealth_value'] as num? ?? 0
                : user['charm_value'] as num? ?? 0;

            final window = levelWindow(configs, currentLevel);
            final prevExp = window.prev?['min_exp'] as num? ?? 0;
            final nextConfig = window.next;
            final nextLevel =
                (nextConfig?['level'] as num?)?.toInt() ?? (currentLevel + 1);
            final nextExp =
                nextConfig?['min_exp'] as num? ?? (currentValue + 1000);
            final expToNext = nextExp - currentValue;
            final progress = calculateLevelProgress(
              currentValue,
              prevExp,
              nextExp,
            );

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: LevelUserProgressCard(
                key: ValueKey(kind),
                theme: theme,
                username: user['username']?.toString() ?? 'User',
                avatarUrl: user['avatar_url']?.toString(),
                currentLevel: currentLevel,
                nextLevel: nextLevel,
                currentValue: currentValue,
                expToNext: expToNext,
                progress: progress,
              ),
            );
          },
        );
      },
    );
  }
}

class _LevelTabBody extends ConsumerWidget {
  const _LevelTabBody({required this.kind, required this.onRefresh});

  final UserLevelKind kind;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = LevelScreenTheme.forKind(kind);
    final configsAsync = switch (kind) {
      UserLevelKind.wealth => ref.watch(wealthLevelConfigsProvider),
      UserLevelKind.charm => ref.watch(charmLevelConfigsProvider),
      UserLevelKind.agency => ref.watch(agencyLevelConfigsProvider),
    };

    return configsAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: theme.accentColor)),
      error: (error, _) =>
          asyncErrorWidget(error, style: const TextStyle(color: Colors.white)),
      data: (configs) {
        if (kind == UserLevelKind.agency) {
          return _buildAgencyTab(context, ref, theme, configs);
        }

        final userAsync = ref.watch(userProfileProvider);
        return userAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: theme.accentColor),
          ),
          error: (error, _) => asyncErrorWidget(
            error,
            style: const TextStyle(color: Colors.white),
          ),
          data: (user) {
            if (user == null || configs.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: theme.accentColor),
              );
            }

            final currentLevel = kind == UserLevelKind.wealth
                ? (user['wealth_level'] as num?)?.toInt() ?? 0
                : (user['charm_level'] as num?)?.toInt() ?? 1;

            return _buildLevelScroll(
              theme: theme,
              configs: configs,
              currentLevel: currentLevel,
              onRefresh: onRefresh,
              kind: kind,
            );
          },
        );
      },
    );
  }

  Widget _buildAgencyTab(
    BuildContext context,
    WidgetRef ref,
    LevelScreenTheme theme,
    List<Map<String, dynamic>> configs,
  ) {
    final agencyAsync = ref.watch(myAgencyProvider);
    final expAsync = ref.watch(agencyOwnerExpProvider);

    return agencyAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: theme.accentColor)),
      error: (error, _) =>
          asyncErrorWidget(error, style: const TextStyle(color: Colors.white)),
      data: (agency) {
        if (agency == null) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            color: theme.accentColor,
            backgroundColor: theme.backgroundColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'You do not own an agency yet.\nCreate one to start earning Agency EXP.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return expAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: theme.accentColor),
          ),
          error: (error, _) => asyncErrorWidget(
            error,
            style: const TextStyle(color: Colors.white),
          ),
          data: (exp) {
            final currentLevel = agencyLevelFromExp(configs, exp);
            return _buildLevelScroll(
              theme: theme,
              configs: configs,
              currentLevel: currentLevel,
              onRefresh: onRefresh,
              kind: UserLevelKind.agency,
            );
          },
        );
      },
    );
  }

  Widget _buildLevelScroll({
    required LevelScreenTheme theme,
    required List<Map<String, dynamic>> configs,
    required int currentLevel,
    required Future<void> Function() onRefresh,
    required UserLevelKind kind,
  }) {
    final window = levelWindow(configs, currentLevel);
    final nextConfig = window.next;
    final targetConfig =
        nextConfig ?? (configs.isNotEmpty ? configs.first : null);
    final rewards = targetConfig == null
        ? <Map<String, dynamic>>[]
        : rewardAssetsForLevel(kind, targetConfig);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.accentColor,
      backgroundColor: theme.backgroundColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: _kProgressCardOverlap + 88),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LevelInfoCard(theme: theme),
                LevelRewardGrid(
                  theme: theme,
                  rewards: rewards,
                  currentLevel: currentLevel,
                  targetLevel:
                      (targetConfig?['level'] as num?)?.toInt() ??
                      (currentLevel + 1),
                ),
                LevelHowToUpgrade(theme: theme),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 15),
                  child: Text(
                    'Level Experience Requirements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const LevelBadgeTableHeader(),
              ],
            ),
          ),
          LevelBadgeTableSliver(
            levelConfigs: configs,
            kind: kind,
            fallbackIcon: theme.fallbackBadgeIcon,
            fallbackIconColor: theme.accentColor,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}
