import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/router/navigation_utils.dart';

class ProfileVisitorsScreen extends ConsumerWidget {
  final String profileId;

  const ProfileVisitorsScreen({super.key, required this.profileId});

  DateTime? _parseVipUntil(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchVisitors() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('profile_visits')
        .select(
          'visit_count,last_visited_at,users:visitor_id(id,username,avatar_url,short_id,vip_level)',
        )
        .eq('profile_id', profileId)
        .order('last_visited_at', ascending: false)
        .limit(50);

    if (response == null) return [];

    return (response as List).map((row) {
      final user = Map<String, dynamic>.from(row['users'] as Map);
      user['visit_count'] = row['visit_count'];
      user['last_visited_at'] = row['last_visited_at'];
      return user;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vipAsync = ref.watch(userVipProvider);

    return vipAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F0108),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      ),
      error: (e, _) => _lockedScaffold(context),
      data: (vip) {
        final vipLevel = (vip?['vip_level'] as num?)?.toInt() ?? 0;
        final vipUntil = _parseVipUntil(vip?['vip_until']);
        final vipActive =
            vipLevel >= 1 &&
            vipUntil != null &&
            vipUntil.isAfter(DateTime.now());

        if (!vipActive) return _lockedScaffold(context);

        return Scaffold(
          backgroundColor: const Color(0xFF0F0108),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            title: const Text(
              'Visitors',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchVisitors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              }

              if (snapshot.hasError) {
                return _locked(context);
              }

              final visitors = snapshot.data ?? [];
              if (visitors.isEmpty) {
                return const Center(
                  child: Text(
                    'No visitors yet.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: visitors.length,
                itemBuilder: (context, index) {
                  final visitor = visitors[index];
                  final username = visitor['username']?.toString() ?? 'User';
                  final avatarUrl = visitor['avatar_url']?.toString();
                  final shortId = visitor['short_id']?.toString() ?? '';
                  final visitorVip =
                      (visitor['vip_level'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? const Icon(
                                  Iconsax.user,
                                  color: Colors.white54,
                                  size: 18,
                                )
                              : null,
                        ),
                        title: Text(
                          username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: shortId.isNotEmpty
                            ? Text(
                                'ID $shortId',
                                style: const TextStyle(color: Colors.white54),
                              )
                            : null,
                        trailing: visitorVip > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'VIP $visitorVip',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => NavigationUtils.navigateToProfile(
                          context,
                          ref,
                          visitor['id']?.toString() ?? '',
                          openFull: false,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _lockedScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Visitors',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: _locked(context),
    );
  }

  Widget _locked(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.medal_star,
                      size: 48,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'VIP 1 Required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Exclusive feature for VIP members. Unlock to see exactly who viewed your profile and when.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRouter.vipCenter),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Unlock Now',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
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
