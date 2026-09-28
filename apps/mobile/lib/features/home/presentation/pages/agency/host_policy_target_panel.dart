import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/policy_targets_provider.dart';
import 'package:sk_live/core/providers/salary_provider.dart';

class HostPolicyTargetPanel extends ConsumerWidget {
  const HostPolicyTargetPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodInfo = ref.watch(currentPeriodInfoProvider);
    final periodId = periodInfo.valueOrNull?['period_id']?.toString();
    final targetAsync = ref.watch(hostPeriodTargetProvider(periodId));

    return targetAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Text('$e', style: const TextStyle(color: Colors.white54)),
      data: (data) {
        if (data == null) {
          return const Text(
            'No target data',
            style: TextStyle(color: Colors.white54),
          );
        }
        final charm = (data['charm_points'] as num?)?.toInt() ?? 0;
        final level = (data['achieved_level'] as num?)?.toInt() ?? 0;
        final est = (data['estimated_salary_usd'] as num?)?.toDouble() ?? 0;
        final next = data['next_level'] is Map
            ? Map<String, dynamic>.from(data['next_level'] as Map)
            : null;
        final remaining = (next?['remaining'] as num?)?.toInt();
        final nextTarget = (next?['charm_target'] as num?)?.toInt();
        final progress = nextTarget != null && nextTarget > 0
            ? (charm / nextTarget).clamp(0.0, 1.0)
            : (level > 0 ? 1.0 : 0.0);
        final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Period ${data['start_date']} → ${data['end_date']}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Text(
              'Payout date: ${data['payout_date']} (to agency owner)',
              style: const TextStyle(color: Colors.amber, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D1B4E), Color(0xFF1A1A2E)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.purpleAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Charm this period',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.compact().format(charm),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'LV $level',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Est. ${money.format(est)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        color: Colors.purpleAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next LV ${next['level']}: ${NumberFormat.compact().format(remaining ?? 0)} charm left',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                data['note']?.toString() ??
                    'Period salary goes to the agency owner. They pay you cash offline.',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
