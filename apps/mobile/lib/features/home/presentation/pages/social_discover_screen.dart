import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/party_people_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/party_profile_card.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_background.dart';
import 'package:sk_live/features/home/presentation/widgets/home_ref_tab_bar.dart';
import 'package:sk_live/features/home/presentation/widgets/party_ref_widgets.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

enum PartyFeedFilter { people, following, joined, recently }

class SocialDiscoverScreen extends ConsumerStatefulWidget {
  const SocialDiscoverScreen({super.key});

  @override
  ConsumerState<SocialDiscoverScreen> createState() =>
      _SocialDiscoverScreenState();
}

class _SocialDiscoverScreenState extends ConsumerState<SocialDiscoverScreen>
    with SingleTickerProviderStateMixin {
  PartyFeedFilter _filter = PartyFeedFilter.people;

  late final TabController _titleTab = TabController(length: 1, vsync: this);
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _titleTab.dispose();
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

  Future<void> _onRefresh() async {
    switch (_filter) {
      case PartyFeedFilter.people:
        ref.invalidate(partyPeopleProvider);
      case PartyFeedFilter.following:
        ref.invalidate(partyFollowingProvider);
      case PartyFeedFilter.joined:
        ref.invalidate(partyJoinedProvider);
      case PartyFeedFilter.recently:
        ref.invalidate(partyRecentlyProvider);
    }
    ref.invalidate(partyFeaturedUserProvider);
  }

  AsyncValue<List<PartyProfileEntry>> _feedForFilter() {
    switch (_filter) {
      case PartyFeedFilter.people:
        return ref.watch(partyPeopleProvider);
      case PartyFeedFilter.following:
        return ref.watch(partyFollowingProvider);
      case PartyFeedFilter.joined:
        return ref.watch(partyJoinedProvider);
      case PartyFeedFilter.recently:
        return ref.watch(partyRecentlyProvider);
    }
  }

  Future<void> _openFeaturedRoom(PartyProfileEntry featured) async {
    var room = featured.room;
    if (room == null) {
      room = await fetchRoomForUser(featured.userId);
    }
    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create your room from Home → Mine')),
      );
      return;
    }
    await openRoomLive(context, Map<String, dynamic>.from(room));
  }

  String? _roomCountry(PartyProfileEntry featured) {
    final room = featured.room;
    final own = room?['country_code']?.toString().trim() ?? '';
    if (own.isNotEmpty) return own;
    if (room != null && room['host_id']?.toString() == featured.userId) {
      return ref
          .watch(userProfileProvider)
          .valueOrNull?['country_code']
          ?.toString();
    }
    return null;
  }

  Widget _buildSpotlightCard() {
    final featuredAsync = ref.watch(partyFeaturedUserProvider);
    return featuredAsync.when(
      data: (featured) => featured == null
          ? const SizedBox.shrink()
          : Center(
              child: PartyRefMyRoomCard(
                name: featured.username,
                roomTitle:
                    featured.roomTitle != null && featured.roomTitle!.isNotEmpty
                    ? featured.roomTitle!
                    : 'Tap to open your room',
                avatarUrl: featured.avatarUrl,
                tagLabel: 'My room',
                countryCode: _roomCountry(featured),
                onTap: () => _openFeaturedRoom(featured),
              ),
            ),
      loading: () => const SizedBox(height: 8),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildFeedBody(AsyncValue<List<PartyProfileEntry>> feedAsync) {
    return feedAsync.when(
      data: (entries) {
        final list = _filterBySearch(entries);
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(
                  Iconsax.people,
                  size: 56,
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 12),
                Text(
                  _emptyMessage(),
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
        return Column(
          children: list.map((e) => PartyProfileCard(entry: e)).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  List<PartyProfileEntry> _filterBySearch(List<PartyProfileEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    final q = _searchQuery.toLowerCase();
    return entries.where((e) => e.username.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = _feedForFilter();
    final s = PartyRefLayout.scaleOf(context);

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
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search people…',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textHint),
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              )
            : HomeRefTabBar(
                controller: _titleTab,
                labels: [context.l10n.social_discover],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              onPressed: _closeSearch,
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
            )
          else
            IconButton(
              onPressed: () => setState(() => _isSearching = true),
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
          SizedBox(width: math.max(0, 68 * s - 24)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const HomeRefBackground(
            tabKey: 'party',
            headerBottom: 230,
            fadeEnd: 340,
            dragonFadeFrom: 240,
          ),
          Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      0,
                      4,
                      0,
                      homeTabScrollBottomPadding(context),
                    ),
                    children: [
                      if (!_isSearching) _buildSpotlightCard(),
                      SizedBox(height: PartyRefLayout.cardToChips * s),
                      _buildFilterPills(),
                      SizedBox(height: PartyRefLayout.chipsToFeed * s),
                      _buildFeedBody(feedAsync),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _emptyMessage() {
    switch (_filter) {
      case PartyFeedFilter.people:
        return 'No profiles yet.\nAdd About & cover photos in My Profile.';
      case PartyFeedFilter.following:
        return 'Follow creators to see them here.';
      case PartyFeedFilter.joined:
        return 'Join rooms to meet other members.';
      case PartyFeedFilter.recently:
        return 'No new rooms yet.';
    }
  }

  Widget _buildFilterPills() {
    const labels = {
      PartyFeedFilter.people: 'People',
      PartyFeedFilter.following: 'Following',
      PartyFeedFilter.joined: 'Joined',
      PartyFeedFilter.recently: 'Recently',
    };

    return PartyRefFilterChips<PartyFeedFilter>(
      values: PartyFeedFilter.values,
      selected: _filter,
      labelOf: (f) => labels[f]!,
      onSelect: (f) => setState(() => _filter = f),
    );
  }
}
