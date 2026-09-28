import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/agency_list_provider.dart';
import 'package:sk_live/features/auth/presentation/pages/application_form_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency_profile_screen.dart';
import 'package:sk_live/features/home/presentation/pages/gift_center_screen.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyScreen extends ConsumerStatefulWidget {
  const AgencyScreen({super.key});

  @override
  ConsumerState<AgencyScreen> createState() => _AgencyScreenState();
}

class _AgencyScreenState extends ConsumerState<AgencyScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _headerColor = Color(0xFF1B1F3B);
  static const _pageBg = Color(0xFFE9E0F5);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRankingList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const GiftCenterScreen(initialPage: 3, initialPeriod: 'Day'),
      ),
    );
  }

  void _openCreateAgency() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ApplicationFormScreen(type: 'agency'),
      ),
    );
  }

  String _flagForCountry(String? code) {
    if (code == null || code.isEmpty) return '🏳️';
    try {
      return Country.parse(code).flagEmoji;
    } catch (_) {
      return '🏳️';
    }
  }

  List<AgencyListItem> _filterAgencies(List<AgencyListItem> agencies) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return agencies;
    return agencies.where((agency) {
      return agency.name.toLowerCase().contains(q) ||
          agency.agencyCode.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final agenciesAsync = ref.watch(recommendedAgenciesProvider);

    return Scaffold(
      backgroundColor: _pageBg,
      body: Column(
        children: [
          Container(
            color: _headerColor,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.agency_title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: agenciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => asyncErrorWidget(e),
              data: (agencies) {
                final filtered = _filterAgencies(agencies);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(recommendedAgenciesProvider);
                    await ref.read(recommendedAgenciesProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ActionImageButton(
                              assetPath:
                                  'assets/ranking/agency/ranking_list_button.webp',
                              onTap: _openRankingList,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionImageButton(
                              assetPath:
                                  'assets/ranking/agency/create_agency_button.webp',
                              onTap: _openCreateAgency,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.agency_recommended,
                              style: const TextStyle(
                                color: Color(0xFF4A3F72),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            height: 36,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: context.l10n.agency_searchHint,
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFF7B61C7),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: () => setState(
                                () => _searchQuery = _searchController.text,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              agencies.isEmpty
                                  ? context.l10n.agency_noAgencies
                                  : context.l10n.agency_noMatching,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        )
                      else
                        ...filtered.map(
                          (agency) => _AgencyCard(
                            agency: agency,
                            flag: _flagForCountry(agency.countryCode),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AgencyProfileScreen(agencyId: agency.id),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionImageButton extends StatelessWidget {
  const _ActionImageButton({required this.assetPath, required this.onTap});

  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 2.35,
        child: Image.asset(assetPath, fit: BoxFit.fill),
      ),
    );
  }
}

class _AgencyCard extends StatelessWidget {
  const _AgencyCard({
    required this.agency,
    required this.flag,
    required this.onTap,
  });

  final AgencyListItem agency;
  final String flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = (agency.description?.trim().isNotEmpty ?? false)
        ? agency.description!.trim()
        : context.l10n.agency_welcomeJoin;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 72,
                color: const Color(0xFFF3F0FA),
                child: agency.avatarUrl != null && agency.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: agency.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.business, color: Colors.grey),
                      )
                    : const Icon(Icons.business, color: Colors.grey, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          agency.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'ID:${agency.agencyCode}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const Spacer(),
                      Icon(Iconsax.people, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${agency.memberCount}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
}
