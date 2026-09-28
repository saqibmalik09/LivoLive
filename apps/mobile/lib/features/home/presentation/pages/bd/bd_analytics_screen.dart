import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/bd_center_provider.dart';
import 'package:sk_live/core/providers/staff_portal_provider.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/features/home/presentation/pages/agency_center_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/staff_portal_charts.dart';
import 'package:sk_live/features/home/presentation/widgets/staff_portal_kpi_cards.dart';
import 'package:sk_live/features/home/presentation/widgets/staff_portal_mock.dart';

class BdAnalyticsScreen extends ConsumerStatefulWidget {
  const BdAnalyticsScreen({super.key});

  @override
  ConsumerState<BdAnalyticsScreen> createState() => _BdAnalyticsScreenState();
}

class _BdAnalyticsScreenState extends ConsumerState<BdAnalyticsScreen> {
  bool _ownsAgency = false;
  BusinessStaffProfile? _staff;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final staff = await ref.read(myBusinessStaffProvider.future);
    final owned = await StaffActions.getMyOwnedAgency();
    if (mounted) {
      setState(() {
        _staff = staff;
        _ownsAgency = owned != null;
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(staffPortalHierarchyProvider);
    ref.invalidate(staffPortalChartsProvider);
    final staff = _staff;
    if (staff != null) {
      ref.invalidate(staffAgencyApplicationsProvider(staff.id));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchyAsync = ref.watch(staffPortalHierarchyProvider);
    final chartsAsync = ref.watch(staffPortalChartsProvider);
    final staff = _staff;
    final appsAsync = staff != null
        ? ref.watch(staffAgencyApplicationsProvider(staff.id))
        : null;
    final bdAsync = ref.watch(bdCenterProvider(currentBdPeriodYm()));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            hierarchyAsync.when(
              data: (h) {
                final charts = chartsAsync.valueOrNull;
                final useMock = charts == null
                    ? StaffPortalMock.shouldUseMock(
                        h.stats,
                        StaffPortalCharts.fromHierarchy(h),
                      )
                    : StaffPortalMock.shouldUseMock(h.stats, charts);
                final s = useMock ? StaffPortalMock.stats : h.stats;
                return Column(
                  children: [
                    StaffPortalKpiCards(stats: s, role: 'bd'),
                    const SizedBox(height: 12),
                    StaffPortalEarningsStrip(
                      commission: s.commissionDiamonds,
                      salary: s.salaryDiamonds,
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Text('$e', style: const TextStyle(color: Colors.white38)),
            ),
            const SizedBox(height: 16),
            chartsAsync.when(
              data: (c) {
                final hier = hierarchyAsync.valueOrNull;
                final useMock = hier == null
                    ? StaffPortalMock.shouldUseMock(StaffPortalStats.empty, c)
                    : StaffPortalMock.shouldUseMock(hier.stats, c);
                final charts = useMock ? StaffPortalMock.charts : c;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaffCommissionTrendChart(points: charts.commissionTrend),
                    const SizedBox(height: 12),
                    StaffAgencyBarsChart(agencies: charts.agencyPerformance),
                    const SizedBox(height: 16),
                    const Text(
                      'Top hosts',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (charts.topHosts.isEmpty)
                      const Text(
                        'No host stats yet.',
                        style: TextStyle(color: Colors.white38),
                      )
                    else
                      ...charts.topHosts.take(10).map((host) {
                        final name = host['username']?.toString() ?? 'Host';
                        final diamonds =
                            host['period_diamonds'] ?? host['diamonds'] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                NumberFormat.compact().format(diamonds),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                if (!_ownsAgency)
                  ActionChip(
                    avatar: const Icon(
                      Iconsax.building,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Create Agency',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF2A1458),
                    onPressed: () async {
                      final controller = TextEditingController(
                        text: 'My Agency',
                      );
                      final name = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: const Text(
                            'Create Agency',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(
                                context,
                                controller.text.trim(),
                              ),
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      );
                      if (name == null || name.isEmpty) return;
                      final res = await StaffActions.createOwnAgency(name);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res['message']?.toString() ?? '${res['success']}',
                          ),
                        ),
                      );
                      await _refresh();
                    },
                  )
                else
                  ActionChip(
                    avatar: const Icon(
                      Iconsax.status_up,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Agency Center',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF2A1458),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AgencyCenterScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            bdAsync.when(
              data: (data) {
                final agencies = (data?['agencies'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final hosts = hierarchyAsync.valueOrNull?.treeHosts ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agencies (${agencies.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (agencies.isEmpty)
                      const Text(
                        'No bound agencies',
                        style: TextStyle(color: Colors.white38),
                      )
                    else
                      ...agencies.map((a) {
                        final id = a['id']?.toString();
                        final hostCount = hosts
                            .where((h) => h['agency_id']?.toString() == id)
                            .length;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            a['name']?.toString() ?? 'Agency',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Code ${a['agency_code']} · $hostCount hosts',
                            style: const TextStyle(color: Colors.white38),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    Text(
                      'Hosts (${hosts.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hosts.isEmpty)
                      const Text(
                        'No hosts yet',
                        style: TextStyle(color: Colors.white38),
                      )
                    else
                      ...hosts.take(40).map((h) {
                        final name =
                            h['username']?.toString() ??
                            h['host_username']?.toString() ??
                            'Host';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: h['avatar_url'] != null
                                ? CachedNetworkImageProvider(
                                    h['avatar_url'].toString(),
                                  )
                                : null,
                            child: h['avatar_url'] == null
                                ? const Icon(Icons.person, size: 18)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'ID ${h['short_id'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pending applications',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (appsAsync == null)
              const SizedBox.shrink()
            else
              appsAsync.when(
                data: (apps) {
                  if (apps.isEmpty) {
                    return const Text(
                      'No pending applications.',
                      style: TextStyle(color: Colors.white38),
                    );
                  }
                  return Column(
                    children: apps.map((app) {
                      final user = app['users'] as Map<String, dynamic>?;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          user?['username']?.toString() ?? 'Applicant',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.greenAccent,
                              ),
                              onPressed: () async {
                                await StaffActions.approveAgencyApplication(
                                  app['id'].toString(),
                                );
                                await _refresh();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                await StaffActions.rejectAgencyApplication(
                                  app['id'].toString(),
                                );
                                await _refresh();
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
