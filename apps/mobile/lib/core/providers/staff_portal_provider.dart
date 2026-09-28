import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

List<Map<String, dynamic>> _asMapList(dynamic v) {
  if (v is! List) return [];
  return v.map(_asMap).toList();
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

class StaffPortalStats {
  const StaffPortalStats({
    required this.bdAdminCount,
    required this.bdCount,
    required this.agencyCount,
    required this.hostCount,
    required this.pendingApplications,
    required this.commissionDiamonds,
    required this.salaryDiamonds,
  });

  final int bdAdminCount;
  final int bdCount;
  final int agencyCount;
  final int hostCount;
  final int pendingApplications;
  final int commissionDiamonds;
  final int salaryDiamonds;

  factory StaffPortalStats.fromJson(Map<String, dynamic> json) {
    return StaffPortalStats(
      bdAdminCount: _asInt(json['bd_admin_count']),
      bdCount: _asInt(json['bd_count']),
      agencyCount: _asInt(json['agency_count']),
      hostCount: _asInt(json['host_count']),
      pendingApplications: _asInt(json['pending_applications']),
      commissionDiamonds: _asInt(json['commission_diamonds']),
      salaryDiamonds: _asInt(json['salary_diamonds']),
    );
  }

  static const empty = StaffPortalStats(
    bdAdminCount: 0,
    bdCount: 0,
    agencyCount: 0,
    hostCount: 0,
    pendingApplications: 0,
    commissionDiamonds: 0,
    salaryDiamonds: 0,
  );
}

class StaffPortalHierarchy {
  const StaffPortalHierarchy({
    required this.success,
    required this.periodId,
    required this.me,
    required this.stats,
    required this.treeStaff,
    required this.treeAgencies,
    required this.treeHosts,
  });

  final bool success;
  final String periodId;
  final Map<String, dynamic> me;
  final StaffPortalStats stats;
  final List<Map<String, dynamic>> treeStaff;
  final List<Map<String, dynamic>> treeAgencies;
  final List<Map<String, dynamic>> treeHosts;

  factory StaffPortalHierarchy.fromJson(Map<String, dynamic> json) {
    final tree = _asMap(json['tree']);
    return StaffPortalHierarchy(
      success: json['success'] == true,
      periodId: json['period_id']?.toString() ?? '',
      me: _asMap(json['me']),
      stats: StaffPortalStats.fromJson(_asMap(json['stats'])),
      treeStaff: _asMapList(tree['staff']),
      treeAgencies: _asMapList(tree['agencies']),
      treeHosts: _asMapList(tree['hosts']),
    );
  }
}

class StaffPortalCharts {
  const StaffPortalCharts({
    required this.periodId,
    required this.commissionTrend,
    required this.agencyPerformance,
    required this.topHosts,
    required this.roleBreakdown,
  });

  final String periodId;
  final List<Map<String, dynamic>> commissionTrend;
  final List<Map<String, dynamic>> agencyPerformance;
  final List<Map<String, dynamic>> topHosts;
  final List<Map<String, dynamic>> roleBreakdown;

  factory StaffPortalCharts.fromJson(Map<String, dynamic> json) {
    return StaffPortalCharts(
      periodId: json['period_id']?.toString() ?? '',
      commissionTrend: _asMapList(json['commission_trend']),
      agencyPerformance: _asMapList(json['agency_performance']),
      topHosts: _asMapList(json['top_hosts']),
      roleBreakdown: _asMapList(json['role_breakdown']),
    );
  }

  factory StaffPortalCharts.fromHierarchy(StaffPortalHierarchy h) {
    int hostCharm(Map<String, dynamic> host) {
      final charm = _asInt(host['period_charm']);
      if (charm > 0) return charm;
      return _asInt(host['period_diamonds']);
    }

    final agencyCharm = <String, int>{};
    for (final host in h.treeHosts) {
      final agencyId = host['agency_id']?.toString() ?? '';
      agencyCharm[agencyId] = (agencyCharm[agencyId] ?? 0) + hostCharm(host);
    }

    final agencyPerformance =
        h.treeAgencies.map((a) {
            final id = a['id']?.toString() ?? '';
            final hosts = h.treeHosts.where(
              (x) => x['agency_id']?.toString() == id,
            );
            return {
              'name': a['name'],
              'agency_code': a['agency_code'],
              'hosts': _asInt(a['host_count']),
              'diamonds': agencyCharm[id] ?? 0,
              'charm': agencyCharm[id] ?? 0,
              'on_mic_seconds': hosts.fold<int>(
                0,
                (sum, x) => sum + _asInt(x['period_on_mic_seconds']),
              ),
            };
          }).toList()
          ..sort((a, b) => _asInt(b['charm']).compareTo(_asInt(a['charm'])));

    final topHosts = [...h.treeHosts]
      ..sort((a, b) => hostCharm(b).compareTo(hostCharm(a)));

    final topMapped = topHosts.take(10).map((host) {
      final agency = h.treeAgencies.firstWhere(
        (a) => a['id']?.toString() == host['agency_id']?.toString(),
        orElse: () => <String, dynamic>{},
      );
      final charm = hostCharm(host);
      return {
        'username': host['username'],
        'short_id': host['short_id'],
        'agency_name': agency['name'] ?? '—',
        'diamonds': charm,
        'charm': charm,
        'on_mic_seconds': _asInt(host['period_on_mic_seconds']),
        'valid_days': _asInt(host['period_valid_days']),
      };
    }).toList();

    return StaffPortalCharts(
      periodId: h.periodId,
      commissionTrend: const [],
      agencyPerformance: agencyPerformance,
      topHosts: topMapped,
      roleBreakdown: [
        if (h.stats.bdAdminCount > 0)
          {'role': 'County Admin', 'count': h.stats.bdAdminCount},
        if (h.stats.bdCount > 0) {'role': 'BD', 'count': h.stats.bdCount},
      ],
    );
  }
}

Future<Map<String, dynamic>> _rpcMap(String name) async {
  final raw = await supabase.rpc(name);
  return _asMap(raw);
}

final staffPortalHierarchyProvider = FutureProvider<StaffPortalHierarchy>((
  ref,
) async {
  try {
    final json = await _rpcMap('get_staff_portal_hierarchy');
    if (json.isEmpty) {
      final fallback = await _rpcMap('get_super_bd_hierarchy');
      return StaffPortalHierarchy.fromJson(fallback);
    }
    return StaffPortalHierarchy.fromJson(json);
  } catch (e) {
    try {
      final fallback = await _rpcMap('get_super_bd_hierarchy');
      return StaffPortalHierarchy.fromJson(fallback);
    } catch (e2) {
      return StaffPortalHierarchy.fromJson({
        'success': false,
        'period_id': '',
        'me': {},
        'stats': {},
        'tree': {'staff': [], 'agencies': [], 'hosts': []},
      });
    }
  }
});

final staffPortalChartsProvider = FutureProvider<StaffPortalCharts>((
  ref,
) async {
  final hierarchy = await ref.watch(staffPortalHierarchyProvider.future);
  try {
    final json = await _rpcMap('get_super_bd_chart_analytics');
    final remote = StaffPortalCharts.fromJson(json);
    final fallback = StaffPortalCharts.fromHierarchy(hierarchy);
    return StaffPortalCharts(
      periodId: remote.periodId.isNotEmpty
          ? remote.periodId
          : fallback.periodId,
      commissionTrend: remote.commissionTrend,
      agencyPerformance: remote.agencyPerformance.isNotEmpty
          ? remote.agencyPerformance
          : fallback.agencyPerformance,
      topHosts: remote.topHosts.isNotEmpty
          ? remote.topHosts
          : fallback.topHosts,
      roleBreakdown: remote.roleBreakdown.isNotEmpty
          ? remote.roleBreakdown
          : fallback.roleBreakdown,
    );
  } catch (_) {
    return StaffPortalCharts.fromHierarchy(hierarchy);
  }
});

String formatStaffCompact(num n) {
  final v = n.toDouble();
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  return n.round().toString();
}
