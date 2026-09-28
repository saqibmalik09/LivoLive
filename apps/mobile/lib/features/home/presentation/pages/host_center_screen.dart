import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/providers/salary_provider.dart';
import 'package:sk_live/features/home/presentation/pages/agency/host_policy_target_panel.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class HostCenterScreen extends ConsumerStatefulWidget {
  const HostCenterScreen({super.key});

  @override
  ConsumerState<HostCenterScreen> createState() => _HostCenterScreenState();
}

class _HostCenterScreenState extends ConsumerState<HostCenterScreen> {
  bool _ownsAgency = false;

  @override
  void initState() {
    super.initState();
    _checkAgency();
  }

  Future<void> _checkAgency() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final agency = await Supabase.instance.client
        .from('agency_members')
        .select('agency_id, agencies!inner(is_active)')
        .eq('user_id', userId)
        .maybeSingle();
    if (mounted) setState(() => _ownsAgency = agency != null);
  }

  Future<void> _refresh() async {
    ref.invalidate(currentPeriodInfoProvider);
    ref.invalidate(myPeriodStatsProvider);
    ref.invalidate(mySalaryPayoutsProvider);
    ref.invalidate(myHostPeriodHistoryProvider);
    await _checkAgency();
  }

  @override
  Widget build(BuildContext context) {
    final periodAsync = ref.watch(currentPeriodInfoProvider);
    final statsAsync = ref.watch(myPeriodStatsProvider);
    final payoutsAsync = ref.watch(mySalaryPayoutsProvider);
    final historyAsync = ref.watch(myHostPeriodHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.l10n.host_centerTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: periodAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            asyncErrorWidget(e, style: const TextStyle(color: Colors.white54)),
        data: (period) {
          final stats = statsAsync.value;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Period ${period['start_date']} — ${period['end_date']}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Payout: ${period['payout_date']}',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                  if (!_ownsAgency)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Join an agency to earn charm salary and gift rewards.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const HostPolicyTargetPanel(),
                  const SizedBox(height: 24),
                  _buildCharmCard(
                    (stats?['charm_points'] as num?)?.toInt() ?? 0,
                  ),
                  const SizedBox(height: 16),
                  _buildActivityGraph(stats),
                  const SizedBox(height: 16),
                  _buildStatsGrid(stats),
                  const SizedBox(height: 24),
                  Text(
                    'Period history',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  historyAsync.when(
                    data: (rows) {
                      if (rows.isEmpty) {
                        return const Text(
                          'No past periods yet.',
                          style: TextStyle(color: Colors.white54),
                        );
                      }
                      return Column(
                        children: rows.map((r) {
                          final charm =
                              (r['charm_points'] as num?)?.toInt() ?? 0;
                          final paid = (r['paid_amount'] as num?)?.toInt();
                          final hours =
                              (((r['total_on_mic_seconds'] as num?)?.toInt() ??
                                          0) /
                                      3600)
                                  .floor();
                          final days = (r['valid_days'] as num?)?.toInt() ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['period_id']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Charm $charm · ${hours}h · $days days',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    paid != null ? '+$paid' : '—',
                                    style: TextStyle(
                                      color: paid != null
                                          ? Colors.greenAccent
                                          : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.host_salaryHistory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  payoutsAsync.when(
                    data: (rows) {
                      if (rows.isEmpty) {
                        return Text(
                          context.l10n.host_noSalaryPayouts,
                          style: const TextStyle(color: Colors.white54),
                        );
                      }
                      return Column(
                        children: rows.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${r['period_id']} — ${r['beneficiary_role']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                Text(
                                  '+${r['total_amount']}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _confirmLeaveAgency(context),
                      icon: const Icon(Iconsax.logout, color: Colors.redAccent),
                      label: Text(
                        context.l10n.host_leaveAgency,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.redAccent.withValues(
                          alpha: 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCharmCard(int charm) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE6D08D), Color(0xFFC7A75C)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.host_periodCharm,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Iconsax.heart, color: Colors.black, size: 28),
              const SizedBox(width: 12),
              Text(
                '$charm',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGraph(Map<String, dynamic>? stats) {
    final dailySeconds = stats?['daily_seconds'] as Map<String, dynamic>? ?? {};
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      final dayKey = (i + 1).toString();
      final seconds = dailySeconds[dayKey] as int? ?? 0;
      spots.add(FlSpot(i.toDouble(), seconds / 3600));
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= 7) return const SizedBox.shrink();
                  return Text(
                    days[i],
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orangeAccent,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic>? stats) {
    final seconds = stats?['total_on_mic_seconds'] as int? ?? 0;
    final hours = (seconds / 3600).toStringAsFixed(1);
    final days = stats?['valid_days'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            context.l10n.host_onMicHours,
            hours,
            Iconsax.clock,
            Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatTile(
            context.l10n.host_validDays,
            '$days',
            Iconsax.calendar,
            Colors.purpleAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveAgency(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          l10n.host_leaveAgencyConfirmTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.host_leaveAgencyConfirmBody,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(agencyCenterActionsProvider).leaveMyAgency();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.common_leave),
          ),
        ],
      ),
    );
  }
}
