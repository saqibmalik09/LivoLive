import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';
import 'package:sk_live/core/services/hive_cache_service.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:country_picker/country_picker.dart';
import 'package:sk_live/features/home/presentation/pages/open_party_event.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/room_info_screen.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/party_screen_config_provider.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_background.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_chips_row.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_country_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_room_card.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_tab_bar.dart';
import 'package:sk_live/features/home/presentation/widgets/home_discovery_tab.dart';
import 'package:sk_live/features/home/presentation/widgets/home_party_banner_slider.dart';
import 'package:sk_live/core/widgets/ranking_frame_media.dart';
import 'package:sk_live/features/home/presentation/widgets/party_events_tab.dart';
import 'package:sk_live/features/home/presentation/widgets/home_task_float_button.dart';
import 'package:sk_live/features/home/presentation/widgets/home_search_panel.dart';

import 'package:sk_live/core/providers/room_info_provider.dart';
import 'package:sk_live/core/providers/recent_rooms_provider.dart';
import 'package:sk_live/core/providers/home_provider.dart';
import 'package:sk_live/core/providers/home_rooms_pagination_provider.dart';
import 'package:sk_live/core/providers/room_search_provider.dart';
import 'package:sk_live/core/providers/social_provider.dart';
import 'package:sk_live/core/util/user_search_query.dart';
import 'package:sk_live/core/util/room_cover_cache.dart';
import 'package:sk_live/core/router/navigation_utils.dart';
import 'package:sk_live/core/models/room_category.dart';
import 'package:sk_live/core/providers/rooms_daily_gift_totals_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

List<Country>? _sortedCountriesCache;

/// Every country, priority markets first, then alphabetical.
///
/// The result never changes, but this used to be recomputed on every build of
/// the Room tab — a fresh `getAll()` plus a sort whose comparator ran a linear
/// `indexOf` over the priority list for each comparison. That is a few thousand
/// string compares per frame while the user is scrolling.
List<Country> _countriesByPriority(List<String> priorityCodes) {
  final cached = _sortedCountriesCache;
  if (cached != null) return cached;
  final rank = <String, int>{};
  for (var i = 0; i < priorityCodes.length; i++) {
    rank.putIfAbsent(priorityCodes[i], () => i);
  }
  final sorted = List<Country>.from(CountryService().getAll())
    ..sort((a, b) {
      final aIdx = rank[a.countryCode];
      final bIdx = rank[b.countryCode];
      if (aIdx != null && bIdx != null) return aIdx.compareTo(bIdx);
      if (aIdx != null) return -1;
      if (bIdx != null) return 1;
      return a.name.compareTo(b.name);
    });
  _sortedCountriesCache = sorted;
  return sorted;
}

class PartyScreen extends ConsumerStatefulWidget {
  const PartyScreen({super.key});

  @override
  ConsumerState<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends ConsumerState<PartyScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  int _roomTabFilterIndex = 0;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  final ScrollController _discoveryScrollController = ScrollController();
  final ScrollController _countryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    _tabController.addListener(_onHomeTabChanged);
    _discoveryScrollController.addListener(_onDiscoveryScroll);
    _countryScrollController.addListener(_onCountryScroll);
    _prewarmCachedRoomCovers();
  }

  void _prewarmCachedRoomCovers() {
    final covers = HiveCacheService.loadRoomCovers();
    if (covers == null || covers.isEmpty) return;
    final cacheW = roomCoverCacheWidth();
    Future(() {
      for (final room in covers.take(HiveCacheService.coverLimit)) {
        final raw = room['image_url'] as String?;
        if (raw == null || raw.isEmpty) continue;
        retainRoomCover(raw, cacheW);
      }
    });
  }

  void _onHomeTabChanged() {
    if (_tabController.index != 1) return;
    final country = ref.read(selectedCountryProvider);
    if (country.isNotEmpty) {
      _configureCountryRooms(country);
    }
  }

  void _onDiscoveryScroll() {
    if (!_discoveryScrollController.hasClients) return;
    final pos = _discoveryScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 1200) {
      ref.read(discoveryRoomsPaginationProvider.notifier).loadMore();
    }
  }

  void _onCountryScroll() {
    if (!_countryScrollController.hasClients) return;
    final pos = _countryScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 1200) {
      ref.read(countryRoomsPaginationProvider.notifier).loadMore();
    }
  }

  void _configureCountryRooms(String countryCode) {
    if (countryCode.isEmpty) return;
    ref
        .read(countryRoomsPaginationProvider.notifier)
        .configure(
          countryCode: countryCode,
          topicSlug: RoomCategory.slugForFilterIndex(_roomTabFilterIndex),
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(partyScreenConfigProvider.notifier).checkForUpdatesSilently(),
      );
    }
  }

  void _openMinePanel() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: Text(
              context.l10n.party_mineTitle,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppColors.textPrimary,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _buildMineTab(),
        ),
      ),
    );
  }

  Future<void> _openMyRoom() async {
    final userProfile = ref.read(userProfileProvider).valueOrNull;
    if (userProfile == null) return;

    try {
      var room = await ref.read(roomInfoProvider(null).future);
      if (!mounted) return;

      if (room == null) {
        final created = await ref
            .read(roomInfoProvider(null).notifier)
            .createRoom({
              'host_id': userProfile['id'],
              'title': "${userProfile['username']}'s Room",
            });
        if (!mounted) return;
        room = await ref.read(roomInfoProvider(null).future);
        if (room == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                created
                    ? context.l10n.party_couldNotOpenRoom
                    : 'Could not create or find your room',
              ),
            ),
          );
          return;
        }
      }

      await openRoomLive(context, Map<String, dynamic>.from(room));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.party_couldNotOpenRoom)),
      );
    }
  }

  void _openGiftCenterRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const GiftCenterScreen(initialPage: 0, initialPeriod: 'Day'),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _tabController.removeListener(_onHomeTabChanged);
    _discoveryScrollController.removeListener(_onDiscoveryScroll);
    _countryScrollController.removeListener(_onCountryScroll);
    _discoveryScrollController.dispose();
    _countryScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomInfoProvider(null), (previous, next) {
      if (next is AsyncError && mounted) {
        if (shouldHideErrorFromUsers(next.error)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.party_pullToRefresh),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 0,
        toolbarHeight: 60,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.party_searchHint,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: AppColors.textHint),
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (!mounted) return;
                      setState(() => _searchQuery = value.trim());
                    },
                  );
                },
              )
            : HomeRefTabBar(
                controller: _tabController,
                labels: [
                  context.l10n.party_tabHot,
                  context.l10n.party_tabRoom,
                  context.l10n.party_tabEvent,
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              onPressed: _closeSearch,
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            )
          else ...[
            IconButton(
              onPressed: _openGiftCenterRanking,
              tooltip: context.l10n.party_tooltipRanking,
              icon: HomeRefTabBar.rowIcon(
                context,
                Image.asset(
                  'assets/home/tabs/cup.webp',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _isSearching = true),
              tooltip: context.l10n.party_tooltipSearch,
              icon: HomeRefTabBar.rowIcon(
                context,
                Image.asset(
                  'assets/design/home/top_search_gold.webp',
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            IconButton(
              onPressed: () => unawaited(_openMyRoom()),
              tooltip: context.l10n.party_tooltipMyRoom,
              icon: HomeRefTabBar.rowIcon(
                context,
                Image.asset(
                  'assets/design/home/top_myroom_masjid.webp',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HomeRefBackground(),
          Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              ),
              Expanded(
                child: _isSearching
                    ? HomeSearchPanel(
                        roomsTab: _buildRoomSearchResults(),
                        usersTab: _buildUserSearchResults(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          HomeDiscoveryTab(
                            scrollController: _discoveryScrollController,
                            buildRoomGridWithMidBanner:
                                _buildRoomGridWithMidBanner,
                            buildRoomsShimmer: ({int count = 6}) =>
                                _buildRoomsShimmer(count: count),
                            onTopBannerTap: (banner) =>
                                unawaited(_openTopBanner(banner)),
                            chipsRow: _buildHotChipsRow(),
                          ),
                          _buildCountryTab(),
                          const PartyEventsTab(),
                        ],
                      ),
              ),
            ],
          ),
          const HomeTaskFloatButton(),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyHint({
    required IconData icon,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 56,
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSearchResults() {
    if (!isUserSearchQueryReady(_searchQuery)) {
      return _buildSearchEmptyHint(
        icon: Iconsax.search_normal,
        message: context.l10n.party_typeRoomNameOrId,
      );
    }

    final searchAsync = ref.watch(roomSearchProvider(_searchQuery));

    return searchAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return _buildSearchEmptyHint(
            icon: Iconsax.home,
            message: context.l10n.party_noRoomFound(_searchQuery),
          );
        }

        final giftTotals = _dailyGiftTotalsFor(rooms);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            homeTabScrollBottomPadding(context),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            final id = room['id']?.toString() ?? '';
            return _buildRoomCard(
              room,
              index,
              dailyGiftTotal: giftTotals[id] ?? 0,
            );
          },
        );
      },
      loading: () => _buildRoomsShimmer(),
      error: (err, _) => Center(
        child: Text(
          'Search error: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildUserSearchResults() {
    if (!isUserSearchQueryReady(_searchQuery)) {
      return _buildSearchEmptyHint(
        icon: Iconsax.user_search,
        message: context.l10n.party_typeUsernameOrUid,
      );
    }

    final searchAsync = ref.watch(userSearchProvider(_searchQuery));

    return searchAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return _buildSearchEmptyHint(
            icon: Iconsax.user,
            message: context.l10n.party_noUserFound(_searchQuery),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            12,
            4,
            12,
            homeTabScrollBottomPadding(context),
          ),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final user = users[index];
            final userId = user['id']?.toString() ?? '';
            final avatarUrl = user['avatar_url']?.toString();
            final shortId = user['short_id']?.toString();
            final level = user['user_level'] ?? 1;

            return Material(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (userId.isEmpty) return;
                  NavigationUtils.navigateToProfile(context, ref, userId);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primaryUltraLight,
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                            ? AppNetworkImageProvider(
                                avatarUrl,
                                transformWidth: 128,
                                transformHeight: 128,
                              )
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? const Icon(Iconsax.user, color: AppColors.accent)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['username']?.toString() ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shortId != null
                                  ? 'UID $shortId · Lv $level'
                                  : 'Lv $level',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Iconsax.arrow_right_3,
                        size: 18,
                        color: AppColors.textHint.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Search error: $err',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  List<Widget> _buildRoomGridWithMidBanner(
    List<Map<String, dynamic>> rooms,
    Map<String, int> giftTotals,
  ) {
    const insertAfter = 2;
    final first = rooms.take(insertAfter).toList();
    final rest = rooms.length > insertAfter
        ? rooms.sublist(insertAfter)
        : <Map<String, dynamic>>[];
    final s = HomeRefRoomCard.scaleOf(context);

    Widget gridFor(
      List<Map<String, dynamic>> chunk, {
      required int indexOffset,
    }) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: HomeRefRoomCard.side * s),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: HomeRefRoomCard.cardHeight * s,
            mainAxisSpacing: HomeRefRoomCard.gap * s,
            crossAxisSpacing: HomeRefRoomCard.gap * s,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final room = chunk[index];
              final id = room['id']?.toString() ?? '';
              return RepaintBoundary(
                key: ValueKey('hot-room-$id'),
                child: HomeRefRoomCard(
                  room: room,
                  giftTotal: giftTotals[id] ?? 0,
                  flag: _buildCountryFlag(
                    _roomCountryCode(room),
                    size: 46 * s,
                    lineHeight: 1,
                  ),
                  hostName:
                      room['host_name']?.toString() ??
                      context.l10n.party_unknownHost,
                  locked: roomIsLocked(room),
                  onTap: () =>
                      openRoomLive(context, Map<String, dynamic>.from(room)),
                ),
              );
            },
            childCount: chunk.length,
            // Page is ~24+16 rooms. Keep-alives cover a short scroll; the
            // discovery cache extent still drops cards far off screen.
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: false,
          ),
        ),
      );
    }

    return [
      if (first.isNotEmpty) gridFor(first, indexOffset: 0),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        sliver: SliverToBoxAdapter(
          child: HomePartyBannerSlider(
            placement: 'after_rooms',
            onBannerTap: (banner) => unawaited(_openBannerRoom(banner)),
          ),
        ),
      ),
      if (rest.isNotEmpty) gridFor(rest, indexOffset: first.length),
    ];
  }

  Future<void> _openTopBanner(Map<String, dynamic> banner) async {
    final raw = banner['room_number'];
    final roomNumber = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString().trim() ?? '');
    if (roomNumber != null && roomNumber > 0) {
      await _openBannerRoom(banner);
      return;
    }
    await _openBannerEvent(banner);
  }

  Future<void> _openBannerEvent(Map<String, dynamic> banner) async {
    final eventId = banner['party_event_id']?.toString().trim() ?? '';
    if (eventId.isEmpty) return;

    try {
      PartyEvent? event;
      final cached = ref.read(partyEventsProvider).asData?.value;
      if (cached != null) {
        for (final e in cached) {
          if (e.id == eventId) {
            event = e;
            break;
          }
        }
      }

      if (event == null) {
        final row = await Supabase.instance.client
            .from('party_events')
            .select()
            .eq('id', eventId)
            .maybeSingle();
        if (row != null) {
          event = PartyEvent.fromMap(Map<String, dynamic>.from(row));
        }
      }

      if (!mounted) return;
      if (event == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.party_eventNotFound)),
        );
        return;
      }
      openPartyEvent(context, event);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open event')));
    }
  }

  Future<void> _openBannerRoom(Map<String, dynamic> banner) async {
    final raw = banner['room_number'];
    final roomNumber = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString().trim() ?? '');
    if (roomNumber == null || roomNumber <= 0) return;

    try {
      final row = await Supabase.instance.client
          .from('rooms')
          .select('*, host:host_id(username, avatar_url, short_id)')
          .eq('short_id', roomNumber)
          .eq('is_active', true)
          .maybeSingle();

      if (!mounted) return;

      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.party_roomNotFoundOffline)),
        );
        return;
      }

      final room = Map<String, dynamic>.from(row);
      final host = room['host'];
      if (host is Map) {
        room['host_name'] = host['username'] ?? room['host_name'];
        room['host_avatar'] = host['avatar_url'] ?? room['host_avatar'];
      }
      await openRoomLive(context, room);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.party_couldNotOpenRoomGeneric)),
      );
    }
  }

  String? _visualTopFrameUrl(int index, Map<int, String> topFrames) {
    if (index == 0) return topFrames[1];
    if (index == 1) return topFrames[2];
    if (index == 2) return topFrames[3];
    return null;
  }

  Widget _buildRoomCard(
    Map<String, dynamic> room,
    int index, {
    int dailyGiftTotal = 0,
    bool showTopRankFrames = false,
    Map<int, String> topFrames = const {},
  }) {
    final title = room['title'] ?? 'Room';
    final hostName = room['host_name'] ?? context.l10n.party_unknownHost;
    final onlineCount = (room['online_users_count'] as num?)?.toInt() ?? 0;
    final showFrame =
        showTopRankFrames && _visualTopFrameUrl(index, topFrames) != null;

    return GestureDetector(
      onTap: () => openRoomLive(context, Map<String, dynamic>.from(room)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: room['image_url'] != null
                        ? Builder(
                            builder: (context) {
                              final cacheW = roomCoverCacheWidth(context);
                              return AppNetworkImage(
                                imageUrl: room['image_url'],
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                transformWidth: cacheW,
                                transformHeight: cacheW,
                                memCacheWidth: cacheW,
                                memCacheHeight: cacheW,
                              );
                            },
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
                              ),
                            ),
                          ),
                  ),

                  if (roomIsLocked(room))
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.55),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: Colors.amber,
                        ),
                      ),
                    ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 12,
                            color: Color(0xFFFF8A3D),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            NumberFormatter.format(dailyGiftTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildAvatarStack(
                        room['top_avatars'],
                        onlineCount,
                      ),
                    ),
                  ),

                  if (showFrame)
                    Positioned(
                      top: -6,
                      left: -4,
                      right: -4,
                      bottom: -3,
                      child: IgnorePointer(
                        child: RankingFrameMedia(
                          url: _visualTopFrameUrl(index, topFrames)!,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildCountryFlag(_roomCountryCode(room)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hostName,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 12,
                        color: AppColors.gold.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$onlineCount',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarStack(dynamic avatarsRaw, int totalCount) {
    final List<dynamic> avatars = avatarsRaw is List ? avatarsRaw : [];
    if (avatars.isEmpty && totalCount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatars.isNotEmpty) ...[
            SizedBox(
              width: 16.0 + (avatars.length - 1) * 12.0,
              height: 16,
              child: Stack(
                children: List.generate(avatars.length, (i) {
                  return Positioned(
                    left: i * 12.0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: ClipOval(
                        child: avatars[i] != null
                            ? AppNetworkImage(
                                imageUrl: avatars[i].toString(),
                                transformWidth: 48,
                                transformHeight: 48,
                                memCacheWidth: 48,
                                memCacheHeight: 48,
                                fadeInDuration: Duration.zero,
                                fadeOutDuration: Duration.zero,
                                fit: BoxFit.cover,
                              )
                            : Container(color: AppColors.primaryUltraLight),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$totalCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsShimmer({int count = 6}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMineTab() {
    final userProfileAsync = ref.watch(userProfileProvider);
    final roomInfoAsync = ref.watch(roomInfoProvider(null));
    final userProfile = userProfileAsync.value;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMineSectionHeader(context.l10n.party_myRoom),
            roomInfoAsync.when(
              data: (room) {
                if (room != null) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RoomInfoScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        roomInfoAsync.when(
          data: (room) {
            if (room == null) {
              return _buildCreateRoomSection(userProfile);
            }
            return GestureDetector(
              onTap: () =>
                  openRoomLive(context, Map<String, dynamic>.from(room)),
              child: _buildUserRoomCard(userProfile, room),
            );
          },
          loading: () => Shimmer.fromColors(
            baseColor: AppColors.primaryUltraLight,
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          error: (err, stack) => _buildCreateRoomSection(userProfile),
        ),

        roomInfoAsync.when(
          data: (room) {
            if (room == null) return const SizedBox.shrink();
            final stats = room['room_stats'];
            final int level = (stats is Map
                ? (stats['current_level'] ?? 1)
                : 1);
            final int exp = (stats is Map ? (stats['total_exp'] ?? 0) : 0)
                .toInt();

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GestureDetector(
                onTap: () => GoRouter.of(
                  context,
                ).push('/room-level', extra: {'roomId': room['id']}),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.meeting_room,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.party_roomLevelBadges,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Level $level • $exp Exp',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),
        _buildManagedRoomsSection(),
        const SizedBox(height: 24),
        _buildMineSectionHeader(context.l10n.party_recents, showMore: false),
        _buildRecentRoomsList(),
        const SizedBox(height: 24),
        _buildMineSectionHeader(context.l10n.party_myFollowings),
        _buildFollowedRoomsList(),
      ],
    );
  }

  Widget _buildMineSectionHeader(String title, {bool showMore = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (showMore)
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textHint,
            size: 28,
          ),
      ],
    );
  }

  Widget _buildRecentRoomsList() {
    final recentRoomsAsync = ref.watch(recentRoomsProvider);

    return recentRoomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return _buildEmptyState(context.l10n.party_emptyRecents);
        }

        final displayRooms = rooms.length > 10 ? rooms.sublist(0, 10) : rooms;
        final giftTotals = _dailyGiftTotalsFor(displayRooms);

        return SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayRooms.length,
            itemBuilder: (context, index) {
              final room = displayRooms[index];
              final id = room['id']?.toString() ?? '';
              return Container(
                width: 170,
                margin: const EdgeInsets.only(right: 12),
                child: _buildRoomCard(
                  room,
                  index,
                  dailyGiftTotal: giftTotals[id] ?? 0,
                ),
              );
            },
          ),
        );
      },
      loading: () => SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          itemBuilder: (context, index) => Container(
            width: 170,
            margin: const EdgeInsets.only(right: 12),
            child: Shimmer.fromColors(
              baseColor: AppColors.shimmerBase,
              highlightColor: AppColors.shimmerHighlight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ),
      error: (err, stack) => _buildEmptyState('Error loading recents'),
    );
  }

  Widget _buildManagedRoomsSection() {
    final managedRoomsAsync = ref.watch(managedRoomsProvider);

    return managedRoomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) return const SizedBox.shrink();

        final giftTotals = _dailyGiftTotalsFor(rooms);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMineSectionHeader(context.l10n.party_managedRooms),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final id = room['id']?.toString() ?? '';
                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildRoomCard(
                      room,
                      index,
                      dailyGiftTotal: giftTotals[id] ?? 0,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildUserRoomCard(
    Map<String, dynamic>? profile,
    Map<String, dynamic>? room,
  ) {
    final String username = profile?['username'] ?? 'User';
    final String status = room != null
        ? RoomCategory.labelFor(room['room_topic'] as String?)
        : (profile?['bio'] ?? context.l10n.party_defaultBio);
    final String roomTitle = room?['title'] ?? '$username\'s Room';
    final String? avatarUrl = room?['image_url'] ?? profile?['avatar_url'];
    final roomCountry = room == null ? '' : _roomCountryCode(room);
    final String countryCode = roomCountry.isNotEmpty
        ? roomCountry
        : (profile?['country_code']?.toString() ?? '');

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF4A148C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
        gradient: const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/auth/login_bg.webp',
                repeat: ImageRepeat.repeat,
                scale: 5,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: avatarUrl != null
                        ? AppNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            transformWidth: 200,
                            transformHeight: 200,
                            memCacheWidth: 200,
                          )
                        : Center(
                            child: Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildCountryFlag(countryCode),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3949AB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            roomTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        color: AppColors.gold,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '0',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roomCountryCode(Map<String, dynamic> room) {
    for (final value in [
      room['country_code'],
      room['host_country_code'],
      room['host'] is Map ? room['host']['country_code'] : null,
      room['users'] is Map ? room['users']['country_code'] : null,
    ]) {
      final code = value?.toString().trim() ?? '';
      if (code.isNotEmpty) return code;
    }
    return '';
  }

  Widget _buildCountryFlag(
    String code, {
    double size = 16,
    double? lineHeight,
  }) {
    final normalized = code.trim().toUpperCase();
    if (normalized.length < 2) {
      return Text(
        '🏳️',
        style: TextStyle(fontSize: size, height: lineHeight),
      );
    }
    try {
      return Text(
        Country.parse(normalized).flagEmoji,
        style: TextStyle(fontSize: size, height: lineHeight),
      );
    } catch (_) {
      final c0 = normalized.codeUnitAt(0);
      final c1 = normalized.codeUnitAt(1);
      if (c0 < 0x41 || c0 > 0x5A || c1 < 0x41 || c1 > 0x5A) {
        return Text(
          '🏳️',
          style: TextStyle(fontSize: size, height: lineHeight),
        );
      }
      final flag =
          String.fromCharCode(c0 - 0x41 + 0x1F1E6) +
          String.fromCharCode(c1 - 0x41 + 0x1F1E6);
      return Text(
        flag,
        style: TextStyle(fontSize: size, height: lineHeight),
      );
    }
  }

  Widget _buildCreateRoomSection(Map<String, dynamic>? userProfile) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        _buildUserRoomCard(userProfile, null),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: ElevatedButton(
            onPressed: () async {
              if (userProfile != null) {
                final created = await ref
                    .read(roomInfoProvider(null).notifier)
                    .createRoom({
                      'host_id': userProfile['id'],
                      'title': '${userProfile['username']}\'s Room',
                    });
                if (!context.mounted) return;
                if (!created) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.party_alreadyHaveRoom)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(context.l10n.common_create),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowedRoomsList() {
    final followedRoomsAsync = ref.watch(followedRoomsProvider);

    return followedRoomsAsync.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return _buildEmptyState(context.l10n.party_emptyFollowings);
        }

        final giftTotals = _dailyGiftTotalsFor(rooms);
        return SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final id = room['id']?.toString() ?? '';
              return Container(
                width: 170,
                margin: const EdgeInsets.only(right: 12),
                child: _buildRoomCard(
                  room,
                  index,
                  dailyGiftTotal: giftTotals[id] ?? 0,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => _buildEmptyState('Error loading followed rooms'),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Iconsax.box,
            size: 80,
            color: AppColors.primary.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryTab() {
    final userProfileAsync = ref.watch(userProfileProvider);
    final selectedCountry = ref.watch(selectedCountryProvider);
    final roomsState = ref.watch(countryRoomsPaginationProvider);

    final profile = userProfileAsync.value;
    if (profile != null && selectedCountry.isEmpty) {
      final profileCountry = profile['country_code'] as String?;
      if (profileCountry != null && profileCountry.isNotEmpty) {
        Future.microtask(
          () =>
              ref.read(selectedCountryProvider.notifier).state = profileCountry,
        );
      }
    }

    ref.listen(userProfileProvider, (previous, next) {
      if (next.hasValue && next.value != null && selectedCountry.isEmpty) {
        final profileCountry = next.value!['country_code'] as String?;
        if (profileCountry != null && profileCountry.isNotEmpty) {
          ref.read(selectedCountryProvider.notifier).state = profileCountry;
        }
      }
    });

    ref.listen(selectedCountryProvider, (previous, next) {
      if (next.isNotEmpty) {
        _configureCountryRooms(next);
      }
    });

    if (selectedCountry.isNotEmpty &&
        roomsState.rooms.isEmpty &&
        !roomsState.isLoading &&
        roomsState.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _configureCountryRooms(selectedCountry);
      });
    }

    const priorityCodes = [
      'PK',
      'SA',
      'AE',
      'IN',
      'BD',
      'US',
      'TR',
      'QA',
      'KW',
      'OM',
      'DZ',
      'AG',
      'AR',
      'AZ',
      'BH',
      'BS',
      'BB',
      'BD',
    ];
    final sortedCountries = _countriesByPriority(priorityCodes);

    final giftTotals = roomsState.giftTotals;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(countryRoomsPaginationProvider.notifier).refresh();
      },
      color: AppColors.primary,
      child: CustomScrollView(
        controller: _countryScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildCountriesRegionSection(
              sortedCountries,
              selectedCountry,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildRoomTabCategoryBar(),
            ),
          ),
          if (selectedCountry.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (roomsState.isLoading && roomsState.rooms.isEmpty)
            SliverToBoxAdapter(child: _buildRoomsShimmer(count: 6))
          else if (roomsState.error != null && roomsState.rooms.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: shouldHideErrorFromUsers(roomsState.error)
                    ? const SizedBox.shrink()
                    : Text(
                        context.l10n.party_pullToRefresh,
                        style: const TextStyle(color: Colors.red),
                      ),
              ),
            )
          else if (roomsState.rooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.location,
                      size: 64,
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.party_noRoomsFromCountry,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.84,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final room = roomsState.rooms[index];
                  final id = room['id']?.toString() ?? '';
                  return RepaintBoundary(
                    child: _buildRoomTabCard(
                      room,
                      index,
                      dailyGiftTotal: giftTotals[id] ?? 0,
                    ),
                  );
                }, childCount: roomsState.rooms.length),
              ),
            ),
          if (roomsState.isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _buildRoomsShimmer(count: 2),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: homeTabScrollBottomPadding(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountriesRegionSection(
    List<Country> countries,
    String selectedCountry,
  ) {
    final preview = countries.take(6).toList();
    if (selectedCountry.isNotEmpty &&
        !preview.any((c) => c.countryCode == selectedCountry)) {
      final selected = countries.firstWhere(
        (c) => c.countryCode == selectedCountry,
        orElse: () => preview.first,
      );
      if (preview.isNotEmpty) preview[preview.length - 1] = selected;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.party_countriesRegion,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              GestureDetector(
                onTap: _pickCountryForRoomTab,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 6),
            Row(
              children: List.generate(3, (col) {
                final index = row * 3 + col;
                if (index >= preview.length) {
                  return const Expanded(child: SizedBox.shrink());
                }
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: col > 0 ? 6 : 0),
                    child: _buildCountryGridTile(
                      preview[index],
                      selectedCountry == preview[index].countryCode,
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountryGridTile(Country country, bool isSelected) {
    return GestureDetector(
      onTap: () => ref.read(selectedCountryProvider.notifier).state =
          country.countryCode,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentSoft
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                country.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accentDark
                      : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotChipsRow() {
    final countries = [
      for (final code in _hotChipCountryCodes)
        (code: code, label: Country.parse(code).name),
    ];
    return HomeRefChipsRow(
      popularLabel: context.l10n.party_tabHot,
      countries: countries,
      onCountryTap: _openRoomTabForCountry,
      onFilterTap: () =>
          _pickCountryForRoomTab(onPicked: () => _tabController.animateTo(1)),
    );
  }

  static const List<String> _hotChipCountryCodes = ['PK', 'SA', 'AE', 'IN'];

  void _openRoomTabForCountry(String countryCode) {
    ref.read(selectedCountryProvider.notifier).state = countryCode;
    _tabController.animateTo(1);
  }

  void _pickCountryForRoomTab({VoidCallback? onPicked}) {
    HomeRefCountrySheet.show(
      context,
      selectedCode: ref.read(selectedCountryProvider),
      onSelect: (Country country) {
        ref.read(selectedCountryProvider.notifier).state = country.countryCode;
        onPicked?.call();
      },
    );
  }

  Widget _buildRoomTabCategoryBar() {
    final filters = RoomCategory.roomTabFilterLabels;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isActive = _roomTabFilterIndex == index;
          return GestureDetector(
            onTap: () {
              if (_roomTabFilterIndex == index) return;
              setState(() => _roomTabFilterIndex = index);
              final country = ref.read(selectedCountryProvider);
              if (country.isNotEmpty) {
                _configureCountryRooms(country);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                filters[index],
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, int> _dailyGiftTotalsFor(List<Map<String, dynamic>> rooms) {
    final key = roomsDailyGiftTotalsKey(rooms);
    if (key.isEmpty) return const {};
    return ref.watch(roomsDailyGiftTotalsProvider(key)).valueOrNull ?? const {};
  }

  Widget _buildRoomTabCard(
    Map<String, dynamic> room,
    int index, {
    int dailyGiftTotal = 0,
  }) {
    final title = room['title'] ?? 'Room';
    final countryCode = _roomCountryCode(room);
    final category = RoomCategory.resolve(room['room_topic'] as String?);
    final typeLabel = category.label;

    return GestureDetector(
      onTap: () => openRoomLive(context, Map<String, dynamic>.from(room)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  room['image_url'] != null
                      ? Builder(
                          builder: (context) {
                            final cacheW = roomCoverCacheWidth(context);
                            return AppNetworkImage(
                              imageUrl: room['image_url'],
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              transformWidth: cacheW,
                              transformHeight: cacheW,
                              memCacheWidth: cacheW,
                              memCacheHeight: cacheW,
                            );
                          },
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6B3A10), Color(0xFF4A2800)],
                            ),
                          ),
                        ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.icon,
                                size: 12,
                                color: category.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                typeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (roomIsLocked(room)) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.55),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 12,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 13,
                            color: Color(0xFFFF5A7A),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            NumberFormatter.format(dailyGiftTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _buildAvatarStack(
                      room['top_avatars'],
                      (room['online_users_count'] ?? 0) as int,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCountryFlag(countryCode.toString()),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
