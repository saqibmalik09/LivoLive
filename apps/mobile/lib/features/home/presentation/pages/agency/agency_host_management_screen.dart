import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_application_record_screen.dart';
import 'package:sk_live/features/home/presentation/pages/agency/agency_host_widgets.dart';

class AgencyHostManagementScreen extends ConsumerWidget {
  const AgencyHostManagementScreen({
    super.key,
    required this.agencyId,
    required this.agencyCode,
  });

  final String agencyId;
  final String agencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostsAsync = ref.watch(agencyMembersProvider(agencyId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Host management',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Host',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share your agency code. Hosts can join from Application / Join Agency.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        agencyCode,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: agencyCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                      icon: const Icon(Iconsax.copy, size: 16),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AgencyApplicationRecordScreen(
                      agencyId: agencyId,
                      initialTab: 0,
                    ),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Iconsax.notification, color: Colors.orangeAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Join Requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white24),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Manage hosts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          hostsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('$e', style: const TextStyle(color: Colors.red)),
            data: (hosts) {
              if (hosts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hosts yet',
                    style: TextStyle(color: Colors.white24),
                  ),
                );
              }
              return Column(
                children: hosts.map((host) {
                  final user = host['users'] as Map<String, dynamic>?;
                  final name = user?['username']?.toString() ?? 'Host';
                  final avatar = user?['avatar_url']?.toString();
                  final uid = user?['id']?.toString() ?? '';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: uid.isEmpty
                          ? null
                          : () => showAgencyHostPerformanceSheet(
                              context: context,
                              ref: ref,
                              agencyId: agencyId,
                              userId: uid,
                              username: name,
                              avatarUrl: avatar,
                              onRemoved: () => ref.invalidate(
                                agencyMembersProvider(agencyId),
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: avatar != null
                                  ? CachedNetworkImageProvider(avatar)
                                  : null,
                              child: avatar == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    host['role']?.toString() ?? 'host',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
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
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
