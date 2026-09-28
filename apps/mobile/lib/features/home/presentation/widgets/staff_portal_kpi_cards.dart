import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/staff_portal_provider.dart';

class StaffPortalKpiCards extends StatelessWidget {
  const StaffPortalKpiCards({
    super.key,
    required this.stats,
    required this.role,
  });

  final StaffPortalStats stats;
  final String role;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, Color color, IconData icon})>[];

    if (role == 'super_bd') {
      items.add((
        label: 'County Admins',
        value: stats.bdAdminCount,
        color: const Color(0xFFF59E0B),
        icon: Iconsax.crown_1,
      ));
      items.add((
        label: 'BDs',
        value: stats.bdCount,
        color: const Color(0xFFA855F7),
        icon: Iconsax.people,
      ));
    } else if (role == 'bd_admin' || role == 'county_admin') {
      items.add((
        label: 'BDs',
        value: stats.bdCount,
        color: const Color(0xFFA855F7),
        icon: Iconsax.people,
      ));
    }

    items.addAll([
      (
        label: 'Agencies',
        value: stats.agencyCount,
        color: const Color(0xFF3B82F6),
        icon: Iconsax.building,
      ),
      (
        label: 'Hosts',
        value: stats.hostCount,
        color: const Color(0xFF10B981),
        icon: Iconsax.microphone,
      ),
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: item.color, size: 18),
                        const SizedBox(height: 10),
                        Text(
                          formatStaffCompact(item.value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class StaffPortalEarningsStrip extends StatelessWidget {
  const StaffPortalEarningsStrip({
    super.key,
    required this.commission,
    required this.salary,
  });

  final int commission;
  final int salary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _earnCard(
            'Gift commission',
            commission,
            const Color(0xFFA855F7),
            Iconsax.diamonds,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _earnCard(
            'Salary paid',
            salary,
            const Color(0xFF10B981),
            Iconsax.wallet_3,
          ),
        ),
      ],
    );
  }

  Widget _earnCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 8),
          Text(
            formatStaffCompact(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
