import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/constants/app_layout.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/party_people_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/party_profile_card.dart';
import 'package:sk_live/features/home/presentation/widgets/party_screen_background.dart';
import 'package:sk_live/features/home/services/room_lock_service.dart';

enum PartyFeedFilter { people, following, joined, recently }

class SocialDiscoverScreen extends ConsumerStatefulWidget {
  const SocialDiscoverScreen({super.key});

  @override
  ConsumerState<SocialDiscoverScreen> createState() =>
      _SocialDiscoverScreenState();
}

class _SocialDiscoverScreenState extends ConsumerState<SocialDiscoverScreen> {
  PartyFeedFilter _filter = PartyFeedFilter.people;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
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

  Widget _buildSpotlightCard() {
    final featuredAsync = ref.watch(partyFeaturedUserProvider);
    return featuredAsync.when(
      data: (featured) => featured == null
          ? const SizedBox.shrink()
          : _SpotlightCard(
              entry: featured,
              onTap: () => _openFeaturedRoom(featured),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
            : Text(
                context.l10n.social_discover,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
              icon: const Icon(Iconsax.search_normal, color: AppColors.primary),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PartyScreenBackground(),
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 60),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      homeTabScrollBottomPadding(context),
                    ),
                    children: [
                      if (!_isSearching) _buildSpotlightCard(),
                      _buildFilterPills(),
                      const SizedBox(height: 10),
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

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 4),
        children: PartyFeedFilter.values.map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent, width: 1),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[f]!,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.entry, required this.onTap});

  final PartyProfileEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white24,
              backgroundImage:
                  entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(entry.avatarUrl!)
                  : null,
              child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                  ? const Icon(Iconsax.user, color: Colors.white, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'My room',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.roomTitle != null && entry.roomTitle!.isNotEmpty
                        ? entry.roomTitle!
                        : 'Tap to open your room',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Iconsax.arrow_right_3, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }
}
