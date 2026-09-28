import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

class AgencyMyDataScreen extends ConsumerStatefulWidget {
  const AgencyMyDataScreen({super.key, required this.agencyId});

  final String agencyId;

  @override
  ConsumerState<AgencyMyDataScreen> createState() => _AgencyMyDataScreenState();
}

class _AgencyMyDataScreenState extends ConsumerState<AgencyMyDataScreen> {
  bool _loading = true;
  int _totalAgencyAmount = 0;
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _settlements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    final access = await ref.read(agencyCenterAccessProvider.future);
    final ownerId = access?.agency['owner_id']?.toString() ?? user?.id;
    if (ownerId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final logs = await Supabase.instance.client
          .from('earning_logs')
          .select('agency_amount, host_amount, total_gift_value, created_at')
          .eq('agency_owner_id', ownerId)
          .order('created_at', ascending: false)
          .limit(40);

      var total = 0;
      final list = <Map<String, dynamic>>[];
      for (final row in logs as List) {
        final m = Map<String, dynamic>.from(row as Map);
        total += (m['agency_amount'] as num?)?.toInt() ?? 0;
        list.add(m);
      }

      List<Map<String, dynamic>> payouts = [];
      try {
        final p = await Supabase.instance.client
            .from('host_salary_payouts')
            .select()
            .eq('beneficiary_user_id', ownerId)
            .eq('beneficiary_role', 'agency')
            .order('created_at', ascending: false)
            .limit(20);
        payouts = List<Map<String, dynamic>>.from(p as List);
      } catch (_) {}

      List<Map<String, dynamic>> settlements = [];
      try {
        final s = await Supabase.instance.client.rpc(
          'get_my_agency_settlement_history',
          params: {'p_agency_id': widget.agencyId, 'p_limit': 24},
        );
        final map = Map<String, dynamic>.from(s as Map);
        if (map['success'] == true && map['rows'] is List) {
          settlements = (map['rows'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _totalAgencyAmount = total;
          _recent = list;
          _payouts = payouts;
          _settlements = settlements;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('My data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(userProfileProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('My Data', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E4B), Color(0xFF0F3D32)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My agency earnings',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          NumberFormat.decimalPattern().format(
                            _totalAgencyAmount,
                          ),
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Recent commission logs',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_recent.isEmpty)
                    const Text(
                      'No earning logs yet',
                      style: TextStyle(color: Colors.white24),
                    )
                  else
                    ..._recent.take(15).map((r) {
                      final amt = (r['agency_amount'] as num?)?.toInt() ?? 0;
                      final created =
                          DateTime.tryParse(
                            r['created_at']?.toString() ?? '',
                          ) ??
                          DateTime.now();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(created.toLocal()),
                                style: const TextStyle(color: Colors.white38),
                              ),
                            ),
                            Text(
                              '+$amt',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (_settlements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Period settlements',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._settlements.map((s) {
                      final totalUsd =
                          (s['total_usd'] as num?)?.toDouble() ?? 0;
                      final charm = (s['total_charm'] as num?)?.toInt() ?? 0;
                      final lv = (s['achieved_level'] as num?)?.toInt() ?? 0;
                      final status = s['status']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${s['period_id'] ?? ''} · LV $lv · charm ${NumberFormat.compact().format(charm)} · $status',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                symbol: '\$',
                                decimalDigits: 2,
                              ).format(totalUsd),
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Period settlements',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No settlement history yet. Past periods stay listed after rollover.',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ],
                  if (_payouts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Salary payouts',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ..._payouts.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${p['period_id'] ?? ''} · ${p['status'] ?? ''}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            Text(
                              '${p['total_amount'] ?? p['diamonds'] ?? p['amount'] ?? ''}',
                              style: const TextStyle(color: Colors.white38),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}
