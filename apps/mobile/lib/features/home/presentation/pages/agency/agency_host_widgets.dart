import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/providers/salary_provider.dart';

void showAgencyHostPerformanceSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String agencyId,
  required String userId,
  required String username,
  String? avatarUrl,
  VoidCallback? onRemoved,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => AgencyHostPerformanceSheet(
      agencyId: agencyId,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      onRemoved: () {
        Navigator.pop(ctx);
        onRemoved?.call();
      },
    ),
  );
}

Future<void> confirmRemoveAgencyHost({
  required BuildContext context,
  required WidgetRef ref,
  required String agencyId,
  required String userId,
  required String username,
  VoidCallback? onRemoved,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('Remove Host?', style: TextStyle(color: Colors.white)),
      content: Text(
        'Remove $username from your agency?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref
        .read(agencyCenterActionsProvider)
        .removeHost(agencyId: agencyId, userId: userId);
    onRemoved?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$username removed from agency')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error removing host')));
    }
  }
}

class AgencyHostPerformanceSheet extends ConsumerStatefulWidget {
  const AgencyHostPerformanceSheet({
    super.key,
    required this.agencyId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.onRemoved,
  });

  final String agencyId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final VoidCallback onRemoved;

  @override
  ConsumerState<AgencyHostPerformanceSheet> createState() =>
      _AgencyHostPerformanceSheetState();
}

class _AgencyHostPerformanceSheetState
    extends ConsumerState<AgencyHostPerformanceSheet> {
  Map<String, dynamic>? _stats;
  int _charmTargetValue = 68000;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final periodId = clientPeriodIdForDate(DateTime.now());
    try {
      final byId = await fetchAgencyMembersPeriodStats(
        agencyId: widget.agencyId,
        periodId: periodId,
        userId: widget.userId,
      );
      final stats = byId[widget.userId];

      int target = 68000;
      try {
        final levels = await Supabase.instance.client
            .from('agency_salary_level_configs')
            .select('charm_target')
            .eq('is_active', true)
            .order('charm_target', ascending: true);
        final charm = (stats?['charm_points'] as num?)?.toInt() ?? 0;
        for (final row in (levels as List)) {
          final t = (row['charm_target'] as num?)?.toInt() ?? 0;
          if (t > charm) {
            target = t;
            break;
          }
          if (t > 0) target = t;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _stats = stats;
          _charmTargetValue = target;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _remove() async {
    try {
      await ref
          .read(agencyCenterActionsProvider)
          .removeHost(agencyId: widget.agencyId, userId: widget.userId);
      widget.onRemoved();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error removing host')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: widget.avatarUrl != null
                    ? CachedNetworkImageProvider(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Period Performance',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            )
          else if (_stats == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No activity recorded for this week.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else ...[
            _progress(
              'Charm',
              _stats!['charm_points'] ?? 0,
              _charmTargetValue,
              Colors.pinkAccent,
            ),
            const SizedBox(height: 20),
            _progress(
              'On-mic Hours',
              ((_stats!['total_on_mic_seconds'] ?? 0) / 3600).floor(),
              40,
              Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            _progress(
              'Valid Days',
              _stats!['valid_days'] ?? 0,
              7,
              Colors.purpleAccent,
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    title: const Text(
                      'Remove Host?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      'Remove ${widget.username} from your agency?',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await _remove();
              },
              icon: const Icon(Iconsax.user_remove, color: Colors.redAccent),
              label: const Text(
                'Remove from Agency',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _progress(String label, num current, num target, Color color) {
    final progress = (current / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              '$current / $target',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
