import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/bd_center_provider.dart';
import 'package:sk_live/core/providers/staff_provider.dart';
import 'package:sk_live/features/home/presentation/pages/agency_center_screen.dart';
import 'package:sk_live/features/home/presentation/pages/bd/bd_analytics_screen.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class BdCenterScreen extends ConsumerStatefulWidget {
  const BdCenterScreen({super.key});

  @override
  ConsumerState<BdCenterScreen> createState() => _BdCenterScreenState();
}

class _BdCenterScreenState extends ConsumerState<BdCenterScreen> {
  late String _period;
  bool _ownsAgency = false;
  BusinessStaffProfile? _staff;

  static const _bg = Color(0xFF0B0E1B);
  static const _card = Color(0xFF14182B);
  static const _border = Color(0xFF3D2A6B);

  static const _newAgencyTiers = <(int, double)>[
    (2, 5),
    (4, 5),
    (5, 10),
    (6, 5),
    (7, 5),
    (8, 5),
  ];

  @override
  void initState() {
    super.initState();
    _period = currentBdPeriodYm();
    _loadStaffMeta();
  }

  Future<void> _loadStaffMeta() async {
    final staff = await ref.read(myBusinessStaffProvider.future);
    final owned = await StaffActions.getMyOwnedAgency();
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _ownsAgency = owned != null;
    });
  }

  Future<void> _createAgency() async {
    final controller = TextEditingController(text: 'My Agency');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text(
          context.l10n.agency_createAgency,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Agency name',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.common_create),
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
          res['success'] == true
              ? 'Agency created. Code: ${res['agency_code']}'
              : res['message']?.toString() ?? context.l10n.common_failed,
        ),
      ),
    );
    if (res['success'] == true) {
      await _loadStaffMeta();
      ref.invalidate(bdCenterProvider(_period));
    }
  }

  void _openAgencyCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgencyCenterScreen()),
    );
  }

  Future<void> _pickPeriod() async {
    final periods = listBdSelectablePeriods(count: 12);
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: periods
              .map(
                (p) => ListTile(
                  title: Text(p, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, p),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _period = picked);
  }

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BdAnalyticsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(bdCenterProvider(_period));
    final settlementHistoryAsync = ref.watch(myBdSettlementHistoryProvider);
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final moneyDec = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.l10n.bd_centerTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            asyncErrorWidget(e, style: const TextStyle(color: Colors.white54)),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'BD access required',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final stats = data['stats'] is Map
              ? Map<String, dynamic>.from(data['stats'] as Map)
              : <String, dynamic>{};
          final next = data['next_level'] is Map
              ? Map<String, dynamic>.from(data['next_level'] as Map)
              : null;
          final levels = (data['levels'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .where((l) => ((l['level'] as num?)?.toInt() ?? 0) > 0)
              .toList();

          final level = (stats['achieved_level'] as num?)?.toInt() ?? 0;
          final total = (stats['est_total_usd'] as num?)?.toDouble() ?? 0;
          final basic = (stats['est_basic_usd'] as num?)?.toDouble() ?? 0;
          final commission =
              (stats['est_commission_usd'] as num?)?.toDouble() ?? 0;
          final newBd = (stats['est_new_bd_usd'] as num?)?.toDouble() ?? 0;
          final target = (stats['agency_target_usd'] as num?)?.toDouble() ?? 0;
          final workDays = (stats['work_days'] as num?)?.toInt() ?? 0;
          final workHours = (stats['work_hours'] as num?)?.toDouble() ?? 0;
          final newAgencies = (stats['new_agencies'] as num?)?.toInt() ?? 0;
          final settleDay = (data['settlement_day'] as num?)?.toInt();
          final tz = data['timezone']?.toString() ?? 'UTC+5';

          final nextLevel =
              (next?['level'] as num?)?.toInt() ?? (level + 1).clamp(1, 10);
          final nextTarget =
              (next?['agency_target_usd'] as num?)?.toDouble() ?? 100;
          final progress = nextTarget > 0
              ? (target / nextTarget).clamp(0.0, 1.0)
              : 0.0;

          final parts = _period.split('-');
          final y = int.tryParse(parts[0]) ?? DateTime.now().year;
          final m = int.tryParse(parts[1]) ?? DateTime.now().month;
          final half = (parts.length >= 3 ? parts[2] : 'B').toUpperCase();
          final DateTime review;
          final payoutRaw = data['payout_date']?.toString();
          final parsedPayout = payoutRaw != null
              ? DateTime.tryParse(payoutRaw)
              : null;
          if (parsedPayout != null) {
            review = parsedPayout;
          } else if (half == 'A') {
            review = DateTime(y, m, settleDay ?? 16);
          } else {
            review = DateTime(y, m + 1, settleDay ?? 1);
          }
          final reviewStr =
              '${review.year}.${review.month.toString().padLeft(2, '0')}.${review.day.toString().padLeft(2, '0')}';

          final newAgencyReward = _newAgencyReward(newAgencies);
          final giftPacks = (data['gift_packs'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final agencies = (data['agencies'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final staffMap = data['staff'] is Map
              ? Map<String, dynamic>.from(data['staff'] as Map)
              : <String, dynamic>{};
          final staffCode =
              staffMap['staff_code']?.toString() ?? _staff?.staffCode ?? '—';
          final staffId = staffMap['id']?.toString() ?? _staff?.id;
          final appsAsync = staffId != null
              ? ref.watch(staffAgencyApplicationsProvider(staffId))
              : null;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bdCenterProvider(_period));
              ref.invalidate(myBdSettlementHistoryProvider);
              if (staffId != null) {
                ref.invalidate(staffAgencyApplicationsProvider(staffId));
              }
              await _loadStaffMeta();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: _pickPeriod,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _period,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openAnalytics,
                      icon: const Icon(
                        Iconsax.chart_2,
                        color: Color(0xFF7EC8FF),
                        size: 18,
                      ),
                      label: const Text(
                        'Analytics',
                        style: TextStyle(
                          color: Color(0xFF7EC8FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _cardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'In progress',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6B3FA0), Color(0xFF3D2A6B)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Iconsax.chart_1,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review Date: $reviewStr($tz). The final amount may vary, please refer to the actual settlement.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          money.format(total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _dottedRow(
                        context.l10n.agency_basicSalary,
                        moneyDec.format(basic),
                      ),
                      _dottedRow(
                        context.l10n.agency_commission,
                        moneyDec.format(commission),
                      ),
                      _dottedRow(
                        context.l10n.bd_newBdCommission,
                        moneyDec.format(newBd),
                      ),
                      _dottedRow(
                        'New Agency Commission',
                        moneyDec.format(newAgencyReward),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The above figures represent estimated earnings; data is updated daily at 00:00 ($tz).',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                _cardBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settlement history',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Past months stay listed after reset so you can see target and paid salary.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      settlementHistoryAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const Text(
                          'Could not load history.',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        data: (rows) {
                          if (rows.isEmpty) {
                            return const Text(
                              'No past months yet.',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            );
                          }
                          return Column(
                            children: rows.map((r) {
                              final ym = r['period_yyyy_mm']?.toString() ?? '';
                              final lv =
                                  (r['achieved_level'] as num?)?.toInt() ?? 0;
                              final targetUsd =
                                  (r['agency_target_usd'] as num?)
                                      ?.toDouble() ??
                                  0;
                              final totalUsd =
                                  (r['total_usd'] as num?)?.toDouble() ?? 0;
                              final status = r['settlement_status']?.toString();
                              final paid = status == 'paid';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ym,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'LV $lv · target ${moneyDec.format(targetUsd)}'
                                            '${status != null ? ' · $status' : ''}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      money.format(totalUsd),
                                      style: TextStyle(
                                        color: paid
                                            ? const Color(0xFF7CFFB2)
                                            : Colors.white70,
                                        fontWeight: FontWeight.w800,
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
                ),
                const SizedBox(height: 14),

                _cardBox(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _levelBadge(
                              'BD LV$level',
                              'Current LV $level',
                              level,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.keyboard_double_arrow_right,
                              color: Colors.white38,
                            ),
                          ),
                          Expanded(
                            child: _levelBadge(
                              'BD LV$nextLevel',
                              'Next stage LV $nextLevel',
                              nextLevel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${money.format(target)} / ${money.format(nextTarget)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _scrollToRewards(context),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2040),
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Details', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _miniStat(
                        'Total Agency Target',
                        money.format(target),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _miniStat(
                        'Work Time',
                        '$workDays D / ${workHours.toStringAsFixed(0)} H',
                        showHelp: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _manageSection(
                  staffCode: staffCode,
                  staffId: staffId,
                  agencies: agencies,
                  appsAsync: appsAsync,
                ),

                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'Reward Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                _rewardProgramCard(
                  title: context.l10n.agency_basicSalary,
                  upTo: _maxOf(levels, 'basic_salary_usd'),
                  description:
                      'If BD rank and working hour requirements are met before monthly settlement, a rank-based reward is deposited into your wallet as cash.',
                  reward: basic,
                  tiers: levels
                      .where(
                        (l) =>
                            ((l['basic_salary_usd'] as num?)?.toDouble() ?? 0) >
                            0,
                      )
                      .map(
                        (l) => (
                          'LV ${l['level']}',
                          (l['basic_salary_usd'] as num?)?.toDouble() ?? 0,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                _rewardProgramCard(
                  title: context.l10n.agency_commission,
                  upTo: _maxOf(levels, 'commission_usd'),
                  description:
                      'Reaching a specific BD level before the settlement date triggers a commission reward deposited into your wallet.',
                  reward: commission,
                  tiers: levels
                      .map(
                        (l) => (
                          'LV ${l['level']}',
                          (l['commission_usd'] as num?)?.toDouble() ?? 0,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                _rewardProgramCard(
                  title: context.l10n.bd_newBdCommission,
                  upTo: _maxOf(levels, 'new_bd_commission_usd'),
                  description:
                      'Limited-time tasks during the first three months after onboarding. If a target BD level is reached before settlement, the reward is deposited as cash.',
                  reward: newBd,
                  tiers: levels
                      .map(
                        (l) => (
                          'LV ${l['level']}',
                          (l['new_bd_commission_usd'] as num?)?.toDouble() ?? 0,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                _rewardProgramCard(
                  title: 'New Agency Commission',
                  upTo: 50,
                  description:
                      'If a newly active agency reaches a designated target before settlement, it becomes eligible for tiered rewards distributed to your wallet as cash.',
                  reward: newAgencyReward,
                  tiers: _newAgencyTiers.map((t) => ('${t.$1}', t.$2)).toList(),
                ),

                const SizedBox(height: 28),
                _giftPackSection(giftPacks),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _manageSection({
    required String staffCode,
    required String? staffId,
    required List<Map<String, dynamic>> agencies,
    required AsyncValue<List<Map<String, dynamic>>>? appsAsync,
  }) {
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agency & Team',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your agency, review applications, and manage bound agencies. Share your BD ID so agencies can apply under you.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: staffCode));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('BD ID copied')));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.personalcard,
                    color: Color(0xFFA78BFA),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BD ID',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          staffCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Iconsax.copy,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!_ownsAgency)
                _manageChip(
                  context.l10n.agency_createAgency,
                  Iconsax.building,
                  _createAgency,
                )
              else
                _manageChip(
                  context.l10n.agency_centerTitle,
                  Iconsax.status_up,
                  _openAgencyCenter,
                ),
              _manageChip('Analytics', Iconsax.chart_2, _openAnalytics),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Bound agencies (${agencies.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (agencies.isEmpty)
            Text(
              'No agencies bound yet.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            )
          else
            ...agencies.take(20).map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Iconsax.building_4,
                      color: Color(0xFF7DD3FC),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['name']?.toString() ?? 'Agency',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Code ${a['agency_code'] ?? '—'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (a['is_active'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF34D399,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          const Text(
            'Pending applications',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (appsAsync == null)
            Text(
              'Loading…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            )
          else
            appsAsync.when(
              data: (apps) {
                if (apps.isEmpty) {
                  return Text(
                    'No pending applications.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  );
                }
                return Column(
                  children: apps.map((app) {
                    final user = app['users'] as Map<String, dynamic>?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          backgroundImage: user?['avatar_url'] != null
                              ? CachedNetworkImageProvider(
                                  user!['avatar_url'].toString(),
                                )
                              : null,
                          child: user?['avatar_url'] == null
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        title: Text(
                          user?['username']?.toString() ?? 'Applicant',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          app['real_name']?.toString() ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
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
                                final res =
                                    await StaffActions.approveAgencyApplication(
                                      app['id'].toString(),
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['success'] == true
                                          ? 'Approved. Code: ${res['agency_code']}'
                                          : res['message']?.toString() ??
                                                'Failed',
                                    ),
                                  ),
                                );
                                if (staffId != null) {
                                  ref.invalidate(
                                    staffAgencyApplicationsProvider(staffId),
                                  );
                                }
                                ref.invalidate(bdCenterProvider(_period));
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                final res =
                                    await StaffActions.rejectAgencyApplication(
                                      app['id'].toString(),
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['success'] == true
                                          ? 'Rejected'
                                          : res['message']?.toString() ??
                                                'Failed',
                                    ),
                                  ),
                                );
                                if (staffId != null) {
                                  ref.invalidate(
                                    staffAgencyApplicationsProvider(staffId),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text(
                '$e',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _manageChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: const Color(0xFF2A1458),
      side: BorderSide(color: const Color(0xFFA78BFA).withValues(alpha: 0.35)),
      onPressed: onTap,
    );
  }

  void _scrollToRewards(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scroll down for Reward Details'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  double _newAgencyReward(int count) {
    double best = 0;
    for (final t in _newAgencyTiers) {
      if (count >= t.$1) best = t.$2;
    }
    return best;
  }

  double _maxOf(List<Map<String, dynamic>> levels, String key) {
    var max = 0.0;
    for (final l in levels) {
      final v = (l[key] as num?)?.toDouble() ?? 0;
      if (v > max) max = v;
    }
    return max;
  }

  Widget _cardBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _dottedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = (c.maxWidth / 6).floor().clamp(4, 40);
                  return Text(
                    List.filled(n, '·').join(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      letterSpacing: 2,
                    ),
                  );
                },
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelBadge(String title, String subtitle, int level) {
    final lv = level.clamp(1, 10);
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: SvgPicture.asset(
            'assets/bd/badges/bd_lv$lv.svg',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, {bool showHelp = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
              if (showHelp) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.help_outline,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardProgramCard({
    required String title,
    required double upTo,
    required String description,
    required double reward,
    required List<(String, double)> tiers,
  }) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.wallet_money,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C1D95).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Up to ${money.format(upTo)}',
                  style: const TextStyle(
                    color: Color(0xFFE9D5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Reward: ${money.format(reward)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tiers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final t = tiers[i];
                return SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      Text(
                        money.format(t.$2),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Iconsax.money_recive,
                          color: Color(0xFFFBBF24),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.$1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _giftPackSection(List<Map<String, dynamic>> giftPacks) {
    final packs = giftPacks.isNotEmpty
        ? giftPacks
        : List.generate(
            10,
            (i) => {
              'level': i + 1,
              'badge_url': null,
              'rewards': <Map<String, dynamic>>[],
            },
          );

    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'BD Gift Pack',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Iconsax.box_1,
                  color: Color(0xFF7DD3FC),
                  size: 40,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Prior to the monthly settlement date, you will qualify for the reward package corresponding to the highest BD tier you have achieved; the package for that tier will be automatically issued on the next settlement date.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.15)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Reward',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...packs.map((pack) {
            final lv = (pack['level'] as num?)?.toInt() ?? 1;
            final badgeUrl = pack['badge_url']?.toString();
            final rewards = (pack['rewards'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final slots = rewards.isNotEmpty
                ? rewards
                : [
                    {
                      'label': 'BD LV$lv',
                      'duration_days': 30,
                      'feature_key': 'bd_frame',
                    },
                    {
                      'label': 'SVIP1',
                      'duration_days': 30,
                      'feature_key': 'svip',
                    },
                    {
                      'label': 'CountryBD',
                      'duration_days': 30,
                      'feature_key': 'country_bd_badge',
                    },
                  ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bdLevelBadge(lv, badgeUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < slots.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(child: _giftRewardTile(slots[i])),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _bdLevelBadge(int level, String? badgeUrl) {
    final localAsset = 'assets/bd/badges/bd_lv$level.svg';
    return SizedBox(
      width: 52,
      height: 52,
      child: badgeUrl != null && badgeUrl.isNotEmpty
          ? Image.network(
              badgeUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  SvgPicture.asset(localAsset, fit: BoxFit.contain),
            )
          : SvgPicture.asset(localAsset, fit: BoxFit.contain),
    );
  }

  Widget _giftRewardTile(Map<String, dynamic> reward) {
    final days = (reward['duration_days'] as num?)?.toInt() ?? 30;
    final label = (reward['label'] ?? reward['shop_item_name'] ?? 'Reward')
        .toString();
    final imageUrl = (reward['display_image_url'] ?? reward['image_url'])
        ?.toString();
    final feature = reward['feature_key']?.toString() ?? '';
    final icon = feature == 'svip'
        ? Iconsax.shield_tick
        : feature == 'country_bd_badge'
        ? Iconsax.medal_star
        : Iconsax.user;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(icon, color: const Color(0xFF7DD3FC), size: 22),
                  )
                : Icon(icon, color: const Color(0xFF7DD3FC), size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            '$label\nx $days days',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
