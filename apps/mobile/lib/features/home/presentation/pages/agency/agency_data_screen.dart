import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/providers/salary_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';

enum _RangeFilter { d7, d30, all }

class AgencyDataScreen extends ConsumerStatefulWidget {
  const AgencyDataScreen({super.key, required this.agencyId});

  final String agencyId;

  @override
  ConsumerState<AgencyDataScreen> createState() => _AgencyDataScreenState();
}

class _AgencyDataScreenState extends ConsumerState<AgencyDataScreen> {
  bool _loading = true;
  _RangeFilter _range = _RangeFilter.d30;
  int _chartMode = 0;

  int _ownerAll = 0;
  int _hostsAll = 0;
  int _grandAll = 0;
  int _hostCount = 0;
  int _ownerRange = 0;
  int _hostsRange = 0;
  int _grandRange = 0;
  int _bestWeek = 0;
  String _bestWeekLabel = '—';
  List<Map<String, dynamic>> _weekly = [];
  List<Map<String, dynamic>> _topHosts = [];
  List<Map<String, dynamic>> _recent = [];
  String _agencyName = '';
  String _periodId = '';

  final _fmt = NumberFormat.compact();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DateTime? get _rangeStart {
    final now = DateTime.now().toUtc();
    switch (_range) {
      case _RangeFilter.d7:
        return now.subtract(const Duration(days: 7));
      case _RangeFilter.d30:
        return now.subtract(const Duration(days: 30));
      case _RangeFilter.all:
        return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final access = await ref.read(agencyCenterAccessProvider.future);
    final ownerId = access?.agency['owner_id']?.toString();
    _agencyName = access?.agency['name']?.toString() ?? 'Agency';
    if (ownerId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      _periodId = clientPeriodIdForDate(DateTime.now());

      final members = await supabase
          .from('agency_members')
          .select('user_id, role, users:user_id(username, avatar_url, id)')
          .eq('agency_id', widget.agencyId);

      final logs = await supabase
          .from('earning_logs')
          .select(
            'agency_amount, host_amount, total_gift_value, host_id, created_at',
          )
          .eq('agency_owner_id', ownerId)
          .order('created_at', ascending: false)
          .limit(2000);

      final start = _rangeStart;
      int ownerAll = 0, hostsAll = 0, grandAll = 0;
      int ownerR = 0, hostsR = 0, grandR = 0;
      final weekAgency = <String, int>{};
      final weekHosts = <String, int>{};
      final weekTotal = <String, int>{};
      final hostTotals = <String, int>{};
      final recent = <Map<String, dynamic>>[];

      for (final row in logs as List) {
        final m = Map<String, dynamic>.from(row as Map);
        final a = (m['agency_amount'] as num?)?.toInt() ?? 0;
        final h = (m['host_amount'] as num?)?.toInt() ?? 0;
        final g = (m['total_gift_value'] as num?)?.toInt() ?? 0;
        final created = DateTime.tryParse(m['created_at']?.toString() ?? '');
        final hostId = m['host_id']?.toString();

        ownerAll += a;
        hostsAll += h;
        grandAll += g;

        final inRange =
            start == null || (created != null && !created.isBefore(start));
        if (inRange) {
          ownerR += a;
          hostsR += h;
          grandR += g;
          if (created != null) {
            final week = _isoWeekId(created.toLocal());
            weekAgency[week] = (weekAgency[week] ?? 0) + a;
            weekHosts[week] = (weekHosts[week] ?? 0) + h;
            weekTotal[week] = (weekTotal[week] ?? 0) + g;
          }
          if (hostId != null && hostId.isNotEmpty) {
            hostTotals[hostId] = (hostTotals[hostId] ?? 0) + h;
          }
          if (recent.length < 12) recent.add(m);
        }
      }

      final weekKeys = {
        ...weekAgency.keys,
        ...weekHosts.keys,
        ...weekTotal.keys,
      }.toList()..sort();

      var best = 0;
      var bestLabel = '—';
      for (final w in weekKeys) {
        final v = weekAgency[w] ?? 0;
        if (v >= best) {
          best = v;
          bestLabel = w;
        }
      }

      final memberMap = <String, Map<String, dynamic>>{};
      for (final row in members as List) {
        final mm = Map<String, dynamic>.from(row as Map);
        final u = mm['users'] as Map<String, dynamic>?;
        final id = u?['id']?.toString() ?? mm['user_id']?.toString();
        if (id != null) memberMap[id] = mm;
      }

      final top = hostTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topIds = top.take(8).map((e) => e.key).toList();

      final profileMap = <String, Map<String, dynamic>>{};
      if (topIds.isNotEmpty) {
        try {
          final profiles = await supabase
              .from('users')
              .select('id, username, avatar_url')
              .inFilter('id', topIds);
          for (final row in profiles as List) {
            final p = Map<String, dynamic>.from(row as Map);
            profileMap[p['id'].toString()] = p;
          }
        } catch (e) {
          debugPrint('Agency host profiles: $e');
        }
      }

      final topHosts = top.take(8).map((e) {
        final m = memberMap[e.key];
        final embedded = m?['users'] as Map<String, dynamic>?;
        final profile = embedded ?? profileMap[e.key];
        return {
          'user_id': e.key,
          'amount': e.value,
          'username': profile?['username'] ?? 'Host',
          'avatar_url': profile?['avatar_url'],
          'role': m?['role'] ?? 'host',
        };
      }).toList();

      try {
        final ids = topHosts.map((e) => e['user_id'] as String).toList();
        if (ids.isNotEmpty) {
          final byId = await fetchAgencyMembersPeriodStats(
            agencyId: widget.agencyId,
            periodId: _periodId,
          );
          for (final h in topHosts) {
            final s = byId[h['user_id'] as String];
            h['period_charm'] = s?['charm_points'] ?? 0;
            h['valid_days'] = s?['valid_days'] ?? 0;
          }
          topHosts.sort((a, b) {
            final bc = (b['period_charm'] as num?)?.toInt() ?? 0;
            final ac = (a['period_charm'] as num?)?.toInt() ?? 0;
            return bc.compareTo(ac);
          });
        }
      } catch (e) {
        debugPrint('Agency period stats: $e');
      }

      if (!mounted) return;
      setState(() {
        _ownerAll = ownerAll;
        _hostsAll = hostsAll;
        _grandAll = grandAll;
        _ownerRange = ownerR;
        _hostsRange = hostsR;
        _grandRange = grandR;
        _hostCount = (members as List).length;
        _bestWeek = best;
        _bestWeekLabel = bestLabel;
        _weekly = weekKeys
            .map(
              (w) => {
                'week': w,
                'agency': weekAgency[w] ?? 0,
                'hosts': weekHosts[w] ?? 0,
                'total': weekTotal[w] ?? 0,
              },
            )
            .toList();
        _topHosts = topHosts;
        _recent = recent;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Agency data load: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _isoWeekId(DateTime d) {
    final thursday = d.add(
      Duration(days: 4 - (d.weekday == 7 ? 0 : d.weekday)),
    );
    final first = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(first).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final share = _grandRange <= 0
        ? 0.0
        : (_ownerRange / _grandRange * 100).clamp(0, 100).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Agency Data',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Iconsax.refresh, color: Colors.white54, size: 20),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            )
          : RefreshIndicator(
              color: Colors.tealAccent,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  _heroCard(share),
                  const SizedBox(height: 14),
                  _rangeChips(),
                  const SizedBox(height: 14),
                  _kpiGrid(),
                  const SizedBox(height: 18),
                  _sectionHeader(
                    context.l10n.agency_earningsTrend,
                    trailing: _chartModeToggle(),
                  ),
                  const SizedBox(height: 10),
                  _advancedChart(),
                  const SizedBox(height: 18),
                  _sectionHeader(context.l10n.agency_topHosts),
                  const SizedBox(height: 10),
                  _topHostsCard(),
                  const SizedBox(height: 18),
                  _sectionHeader('Recent activity'),
                  const SizedBox(height: 10),
                  _recentCard(),
                ],
              ),
            ),
    );
  }

  Widget _heroCard(double share) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12352F), Color(0xFF0F1F3A), Color(0xFF1A1030)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _agencyName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gift volume (selected range)',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_hostCount hosts',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            NumberFormatter.format(_grandRange),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_grandRange <= 0) ? 0 : share / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.tealAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Agency share ${share.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              Text(
                'All-time ${_fmt.format(_grandAll)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeChips() {
    Widget chip(String label, _RangeFilter value) {
      final on = _range == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_range == value) return;
            setState(() => _range = value);
            _load();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on
                  ? Colors.tealAccent
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: on ? Colors.black : Colors.white60,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('7 Days', _RangeFilter.d7),
        const SizedBox(width: 8),
        chip('30 Days', _RangeFilter.d30),
        const SizedBox(width: 8),
        chip('All', _RangeFilter.all),
      ],
    );
  }

  Widget _kpiGrid() {
    final avgWeek = _weekly.isEmpty
        ? 0
        : (_ownerRange / _weekly.length).round();
    final tiles = [
      (
        title: 'Agency cut',
        value: NumberFormatter.format(_ownerRange),
        icon: Iconsax.money_send,
        color: const Color(0xFF34D399),
        sub: 'All-time ${_fmt.format(_ownerAll)}',
      ),
      (
        title: 'Hosts earned',
        value: NumberFormatter.format(_hostsRange),
        icon: Iconsax.user_tag,
        color: const Color(0xFF60A5FA),
        sub: 'All-time ${_fmt.format(_hostsAll)}',
      ),
      (
        title: 'Best week',
        value: NumberFormatter.format(_bestWeek),
        icon: Iconsax.cup,
        color: const Color(0xFFFBBF24),
        sub: _bestWeekLabel,
      ),
      (
        title: 'Avg / week',
        value: NumberFormatter.format(avgWeek),
        icon: Iconsax.chart_21,
        color: const Color(0xFFA78BFA),
        sub: '${_weekly.length} weeks in range',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles
              .map(
                (t) => SizedBox(
                  width: width,
                  child: _kpiTile(
                    t.title,
                    t.value,
                    t.icon,
                    t.color,
                    sub: t.sub,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kpiTile(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? sub,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          if (sub != null)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 9,
                height: 1.2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _chartModeToggle() {
    Widget pill(String label, int mode) {
      final on = _chartMode == mode;
      return GestureDetector(
        onTap: () => setState(() => _chartMode = mode),
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on
                ? Colors.tealAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? Colors.tealAccent : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [pill('Agency', 0), pill('Hosts', 1), pill('Total', 2)],
    );
  }

  Widget _advancedChart() {
    if (_weekly.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No earnings data for this range.',
          style: TextStyle(color: Colors.white24),
        ),
      );
    }

    final key = _chartMode == 0
        ? 'agency'
        : _chartMode == 1
        ? 'hosts'
        : 'total';
    final color = _chartMode == 0
        ? Colors.tealAccent
        : _chartMode == 1
        ? const Color(0xFF60A5FA)
        : const Color(0xFFFBBF24);

    final values = _weekly.map((e) => (e[key] as int)).toList();
    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.25)
        .toDouble()
        .clamp(1.0, double.infinity);
    final width = (_weekly.length * 56.0 + 40)
        .clamp(MediaQuery.of(context).size.width - 32, 2400.0)
        .toDouble();

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1F2937),
                    getTooltipItem: (group, _, rod, __) {
                      final week = _weekly[group.x.toInt()]['week'] as String;
                      return BarTooltipItem(
                        '$week\n${rod.toY.toInt()}',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= _weekly.length) {
                          return const SizedBox();
                        }
                        final week = _weekly[i]['week'] as String;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            week.split('-').last,
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                            ),
                          ),
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.04),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  _weekly.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (_weekly[i][key] as int).toDouble(),
                        width: 14,
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [color.withValues(alpha: 0.35), color],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topHostsCard() {
    if (_topHosts.isEmpty) {
      return _emptyBox('No host earnings in this range.');
    }
    final maxCharm = _topHosts.fold<int>(0, (best, h) {
      final c = (h['period_charm'] as num?)?.toInt() ?? 0;
      return c > best ? c : best;
    });
    final barMax = maxCharm <= 0 ? 1 : maxCharm;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: List.generate(_topHosts.length, (i) {
          final h = _topHosts[i];
          final charm = (h['period_charm'] as num?)?.toInt() ?? 0;
          final avatar = h['avatar_url']?.toString();
          final progress = (charm / barMax).clamp(0.0, 1.0);
          return Padding(
            padding: EdgeInsets.only(
              bottom: i == _topHosts.length - 1 ? 0 : 14,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i < 3 ? Colors.tealAccent : Colors.white38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatar != null
                      ? CachedNetworkImageProvider(avatar)
                      : null,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h['username']?.toString() ?? 'Host',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF60A5FA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Period charm: ${NumberFormatter.format(charm)}',
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  NumberFormatter.format(charm),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _recentCard() {
    if (_recent.isEmpty) return _emptyBox('No recent activity.');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: _recent.map((r) {
          final a = (r['agency_amount'] as num?)?.toInt() ?? 0;
          final h = (r['host_amount'] as num?)?.toInt() ?? 0;
          final g = (r['total_gift_value'] as num?)?.toInt() ?? 0;
          final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.gift,
                    color: Colors.tealAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gift ${NumberFormatter.format(g)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        created == null
                            ? ''
                            : DateFormat(
                                'MMM d, HH:mm',
                              ).format(created.toLocal()),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'A +$a',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'H +$h',
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white24)),
    );
  }
}
