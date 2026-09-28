import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_host_widgets.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyHostListScreen extends ConsumerWidget {
  const AgencyHostListScreen({super.key, required this.agencyId});

  final String agencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(agencyMembersProvider(agencyId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Host List', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: hostsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
        data: (hosts) {
          if (hosts.isEmpty) {
            return const Center(
              child: Text(
                'No hosts in agency yet',
                style: TextStyle(color: Colors.white24),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hosts.length,
            itemBuilder: (context, i) {
              final host = hosts[i];
              final user = host['users'] as Map<String, dynamic>?;
              final name = user?['username']?.toString() ?? 'Host';
              final avatar = user?['avatar_url']?.toString();
              final uid = user?['id']?.toString() ?? '';
              final role = host['role']?.toString() ?? 'host';

              return GestureDetector(
                onTap: uid.isEmpty
                    ? null
                    : () => showAgencyHostPerformanceSheet(
                        context: context,
                        ref: ref,
                        agencyId: agencyId,
                        userId: uid,
                        username: name,
                        avatarUrl: avatar,
                        onRemoved: () =>
                            ref.invalidate(agencyMembersProvider(agencyId)),
                      ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: avatar != null
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: avatar == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              role == 'admin'
                                  ? 'Admin · Tap for performance'
                                  : 'Host · Tap for performance',
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove host',
                        icon: const Icon(
                          Iconsax.user_remove,
                          color: Colors.redAccent,
                        ),
                        onPressed: uid.isEmpty
                            ? null
                            : () => confirmRemoveAgencyHost(
                                context: context,
                                ref: ref,
                                agencyId: agencyId,
                                userId: uid,
                                username: name,
                                onRemoved: () => ref.invalidate(
                                  agencyMembersProvider(agencyId),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
