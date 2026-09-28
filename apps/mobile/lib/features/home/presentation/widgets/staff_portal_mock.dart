import 'package:sk_live/core/providers/staff_portal_provider.dart';

class StaffPortalMock {
  StaffPortalMock._();

  static const stats = StaffPortalStats(
    bdAdminCount: 3,
    bdCount: 12,
    agencyCount: 8,
    hostCount: 46,
    pendingApplications: 2,
    commissionDiamonds: 128450,
    salaryDiamonds: 34200,
  );

  static StaffPortalCharts get charts {
    final now = DateTime.now();
    final trend = List.generate(14, (i) {
      final day = now.subtract(Duration(days: 13 - i));
      final diamonds = 1200 + (i * 180) + ((i % 3) * 450);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return {
        'label': '${months[day.month - 1]} ${day.day}',
        'day': day.toIso8601String().substring(0, 10),
        'diamonds': diamonds,
      };
    });

    return StaffPortalCharts(
      periodId: 'DEMO',
      commissionTrend: trend,
      agencyPerformance: const [
        {
          'name': 'Star Agency',
          'agency_code': '100101',
          'hosts': 12,
          'diamonds': 42000,
          'on_mic_seconds': 180000,
        },
        {
          'name': 'Neon Live',
          'agency_code': '100202',
          'hosts': 9,
          'diamonds': 31500,
          'on_mic_seconds': 142000,
        },
        {
          'name': 'Gold Room',
          'agency_code': '100303',
          'hosts': 7,
          'diamonds': 27800,
          'on_mic_seconds': 98000,
        },
        {
          'name': 'Sky Crew',
          'agency_code': '100404',
          'hosts': 6,
          'diamonds': 19100,
          'on_mic_seconds': 76000,
        },
        {
          'name': 'Pulse Hub',
          'agency_code': '100505',
          'hosts': 5,
          'diamonds': 12400,
          'on_mic_seconds': 54000,
        },
      ],
      topHosts: const [
        {
          'username': 'luna_star',
          'short_id': 100201,
          'agency_name': 'Star Agency',
          'diamonds': 9800,
          'on_mic_seconds': 36000,
          'valid_days': 12,
        },
        {
          'username': 'neon_king',
          'short_id': 100202,
          'agency_name': 'Neon Live',
          'diamonds': 8450,
          'on_mic_seconds': 31000,
          'valid_days': 11,
        },
        {
          'username': 'goldy',
          'short_id': 100203,
          'agency_name': 'Gold Room',
          'diamonds': 7200,
          'on_mic_seconds': 28000,
          'valid_days': 10,
        },
        {
          'username': 'sky_host',
          'short_id': 100204,
          'agency_name': 'Sky Crew',
          'diamonds': 6100,
          'on_mic_seconds': 24000,
          'valid_days': 9,
        },
      ],
      roleBreakdown: const [
        {'role': 'BD Admin', 'count': 3},
        {'role': 'BD', 'count': 12},
      ],
    );
  }

  static bool shouldUseMock(StaffPortalStats stats, StaffPortalCharts charts) {
    final noNetwork =
        stats.agencyCount == 0 &&
        stats.hostCount == 0 &&
        stats.bdAdminCount == 0 &&
        stats.bdCount == 0;
    final flatTrend =
        charts.commissionTrend.isEmpty ||
        charts.commissionTrend.every(
          (p) => ((p['diamonds'] as num?)?.toInt() ?? 0) == 0,
        );
    return noNetwork || flatTrend;
  }
}
