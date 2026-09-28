import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/policy_targets_provider.dart';
import 'package:sk_live/core/providers/salary_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyPeriodSalaryScreen extends ConsumerStatefulWidget {
  const AgencyPeriodSalaryScreen({super.key, required this.agencyId});

  final String agencyId;

  @override
  ConsumerState<AgencyPeriodSalaryScreen> createState() =>
      _AgencyPeriodSalaryScreenState();
}

class _AgencyPeriodSalaryScreenState
    extends ConsumerState<AgencyPeriodSalaryScreen> {
  String? _selectedPeriodId;

  @override
  Widget build(BuildContext context) {
    final periodInfo = ref.watch(currentPeriodInfoProvider);
    final currentPeriodId = periodInfo.valueOrNull?['period_id']?.toString();
    final historyAsync = ref.watch(
      myAgencySettlementHistoryProvider(widget.agencyId),
    );
    final selected = _selectedPeriodId ?? currentPeriodId;
    final dataAsync = ref.watch(
      agencyPeriodTargetsProvider((
        agencyId: widget.agencyId,
        periodId: selected,
      )),
    );
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final historyRows =
        historyAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final periodChips = <String>{
      if (currentPeriodId != null) currentPeriodId,
      ...historyRows
          .map((r) => r['period_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty),
    }.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Period Salary',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No data'));
          }
          final hosts = (data['hosts'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final total = (data['total_usd'] as num?)?.toDouble() ?? 0;
          final charmSal = (data['charm_salary_usd'] as num?)?.toDouble() ?? 0;
          final agentSal = (data['agent_salary_usd'] as num?)?.toDouble() ?? 0;
          final level = (data['achieved_level'] as num?)?.toInt() ?? 0;
          final charm = (data['total_charm'] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                agencyPeriodTargetsProvider((
                  agencyId: widget.agencyId,
                  periodId: selected,
                )),
              );
              ref.invalidate(currentPeriodInfoProvider);
              ref.invalidate(
                myAgencySettlementHistoryProvider(widget.agencyId),
              );
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (periodChips.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: periodChips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final id = periodChips[i];
                        final active = id == selected;
                        return ChoiceChip(
                          label: Text(id),
                          selected: active,
                          onSelected: (_) {
                            setState(() => _selectedPeriodId = id);
                          },
                          selectedColor: const Color(0xFFEDE4FF),
                          labelStyle: TextStyle(
                            color: active
                                ? const Color(0xFF5B2C9D)
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Period ${data['period_id']} · Pay ${data['payout_date']}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F3FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agency LV $level',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total charm: ${NumberFormat.compact().format(charm)}',
                      ),
                      const SizedBox(height: 12),
                      _row('Charm Salary', money.format(charmSal)),
                      _row('Agent Salary', money.format(agentSal)),
                      const Divider(),
                      _row(
                        'Owner wallet (est.)',
                        money.format(total),
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paid to agency owner wallet on payout date. Hosts see estimates only.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hosts',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...hosts.map((h) {
                  final hCharm = (h['charm_points'] as num?)?.toInt() ?? 0;
                  final hLv = (h['achieved_level'] as num?)?.toInt() ?? 0;
                  final hCharmSal =
                      (h['estimated_charm_salary_usd'] as num?)?.toDouble() ??
                      0;
                  final hAgentSal =
                      (h['estimated_agent_salary_usd'] as num?)?.toDouble() ??
                      0;
                  final hEst =
                      (h['estimated_total_usd'] as num?)?.toDouble() ??
                      (hCharmSal + hAgentSal);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(h['username']?.toString() ?? 'Host'),
                    subtitle: Text(
                      'Charm ${NumberFormat.compact().format(hCharm)} · LV $hLv'
                      ' · Host ${money.format(hCharmSal)} + Agent ${money.format(hAgentSal)}',
                    ),
                    trailing: Text(
                      money.format(hEst),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }),
                const SizedBox(height: 28),
                const Text(
                  'Settlement history',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                historyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Text(
                    'Could not load settlement history.',
                    style: TextStyle(color: Colors.black45),
                  ),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Text(
                        'No paid history yet. Past periods stay here after rollover.',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      );
                    }
                    return Column(
                      children: rows.map((r) {
                        final status = r['status']?.toString() ?? '';
                        final totalUsd =
                            (r['total_usd'] as num?)?.toDouble() ?? 0;
                        final charmPts =
                            (r['total_charm'] as num?)?.toInt() ?? 0;
                        final lv = (r['achieved_level'] as num?)?.toInt() ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE8E6F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${r['period_id']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Charm ${NumberFormat.compact().format(charmPts)} · LV $lv · $status',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                money.format(totalUsd),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B5E4B),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.w700 : null),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
          ),
        ],
      ),
    );
  }
}
