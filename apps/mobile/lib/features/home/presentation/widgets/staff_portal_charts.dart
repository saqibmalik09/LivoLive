import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/staff_portal_provider.dart';
import 'package:sk_live/core/util/string_truncate.dart';

class StaffCommissionTrendChart extends StatelessWidget {
  const StaffCommissionTrendChart({super.key, required this.points});

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _emptyPanel('No commission trend yet');
    }

    final spots = <FlSpot>[];
    var maxY = 1.0;
    for (var i = 0; i < points.length; i++) {
      final y = (points[i]['diamonds'] as num?)?.toDouble() ?? 0;
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commission (14 days)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (points.length / 4).clamp(1, 4).toDouble(),
                      getTitlesWidget: (v, _) {
                        final i = v.round();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (i != 0 &&
                            i != points.length ~/ 2 &&
                            i != points.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final label = points[i]['label']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFFF59E0B),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaffAgencyBarsChart extends StatelessWidget {
  const StaffAgencyBarsChart({super.key, required this.agencies});

  final List<Map<String, dynamic>> agencies;

  @override
  Widget build(BuildContext context) {
    final rows = agencies.take(8).toList();
    if (rows.isEmpty) {
      return _emptyPanel('No agency performance yet');
    }

    var maxY = 1.0;
    for (final row in rows) {
      final y =
          (row['charm'] as num?)?.toDouble() ??
          (row['diamonds'] as num?)?.toDouble() ??
          0;
      if (y > maxY) maxY = y;
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agency performance',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (rows.length * 56.0).clamp(280.0, 560.0),
                child: BarChart(
                  BarChartData(
                    maxY: maxY * 1.2,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= rows.length) {
                              return const SizedBox.shrink();
                            }
                            final name =
                                rows[i]['name']?.toString() ?? 'Agency';
                            final short = truncateGraphemes(name, 7);
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                short,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < rows.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY:
                                  (rows[i]['charm'] as num?)?.toDouble() ??
                                  (rows[i]['diamonds'] as num?)?.toDouble() ??
                                  0,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              color: const Color(0xFF3B82F6),
                            ),
                          ],
                        ),
                    ],
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final i = group.x;
                          final name = rows[i]['name']?.toString() ?? 'Agency';
                          return BarTooltipItem(
                            '$name\n${formatStaffCompact(rod.toY)} Charm',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StaffRoleBreakdownChips extends StatelessWidget {
  const StaffRoleBreakdownChips({super.key, required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rows.map((row) {
        final role = row['role']?.toString() ?? 'Role';
        final count = (row['count'] as num?)?.toInt() ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF252540),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$role · $count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

Widget _emptyPanel(String message) {
  return Container(
    height: 120,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Colors.white60, fontSize: 13),
    ),
  );
}
