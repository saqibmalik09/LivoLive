import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/l10n/app_localizations.dart';

final resellerBillsFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'pending',
);

final resellerBillsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final filter = ref.watch(resellerBillsFilterProvider);
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_reseller_withdrawal_bills',
        params: {'p_status': filter, 'p_limit': 50, 'p_offset': 0},
      );

      if (response is Map) {
        final ok = response['success'] == true;
        if (!ok) {
          throw Exception(
            response['message']?.toString() ?? 'Failed to load bills',
          );
        }
        final bills = response['bills'];
        if (bills is List) {
          return List<Map<String, dynamic>>.from(
            bills.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      return [];
    });

String resellerBillStatusLabel(String status, AppLocalizations l10n) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'reseller_approved':
      return l10n.reseller_approvedWaiting;
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

Color resellerBillStatusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFFFB300);
    case 'reseller_approved':
    case 'approved':
      return const Color(0xFF42A5F5);
    case 'completed':
      return const Color(0xFF66BB6A);
    case 'rejected':
    case 'cancelled':
      return const Color(0xFFEF5350);
    default:
      return Colors.white54;
  }
}

class ResellerBillsSection extends ConsumerStatefulWidget {
  const ResellerBillsSection({super.key});

  @override
  ConsumerState<ResellerBillsSection> createState() =>
      _ResellerBillsSectionState();
}

class _ResellerBillsSectionState extends ConsumerState<ResellerBillsSection> {
  bool _busy = false;

  Future<void> _process(String id, String action) async {
    String? note;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final noteCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E30),
          title: Text(
            action == 'approve'
                ? ctx.l10n.reseller_approveBill
                : 'Reject bill?',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action == 'approve'
                    ? 'User will be notified. Admin will credit your reseller stock after completion.'
                    : 'Held cash will be refunded to the user.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Note (optional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => note = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'approve'
                    ? AppColors.primary
                    : Colors.redAccent,
              ),
              onPressed: () {
                note = noteCtrl.text.trim();
                Navigator.pop(ctx, true);
              },
              child: Text(
                action == 'approve' ? 'Approve' : 'Reject',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final res =
          await Supabase.instance.client.rpc(
                'reseller_process_withdrawal',
                params: {
                  'p_id': id,
                  'p_action': action,
                  'p_note': (note != null && note!.isNotEmpty) ? note : null,
                },
              )
              as Map;

      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (res['message']?.toString() ?? 'Done')
                : (res['message']?.toString() ?? 'Failed'),
          ),
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      if (ok) ref.invalidate(resellerBillsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(resellerBillsFilterProvider);
    final billsAsync = ref.watch(resellerBillsProvider);
    const filters = [
      ('pending', 'Pending'),
      ('reseller_approved', 'Approved'),
      ('rejected', 'Rejected'),
      ('all', 'All'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Bills',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Approve or reject cash withdrawals sent to you.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final selected = filter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(resellerBillsFilterProvider.notifier).state = f.$1;
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFF1E1E30),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        billsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: asyncErrorWidget(
              e,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (bills) {
            if (bills.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No bills in this filter',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bills.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final b = bills[i];
                final id = b['id']?.toString() ?? '';
                final status = b['status']?.toString() ?? '';
                final amount = (b['amount'] as num?)?.toDouble() ?? 0;
                final fee = (b['fee'] as num?)?.toDouble() ?? 0;
                final net = (b['net_amount'] as num?)?.toDouble() ?? 0;
                final username = b['requester_username']?.toString() ?? 'User';
                final shortId = b['requester_short_id'];
                final avatar = b['requester_avatar_url']?.toString();
                final pm = b['payment_method'] is Map
                    ? Map<String, dynamic>.from(b['payment_method'] as Map)
                    : <String, dynamic>{};
                final created =
                    DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                    DateTime.now();
                final timeLabel = DateFormat(
                  'yyyy-MM-dd HH:mm',
                ).format(created.toLocal());
                final statusColor = resellerBillStatusColor(status);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.white10,
                            backgroundImage:
                                (avatar != null && avatar.isNotEmpty)
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'ID ${shortId ?? '—'} · $timeLabel',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              resellerBillStatusLabel(status, context.l10n),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${amount.toStringAsFixed(2)}'
                        '  ·  fee \$${fee.toStringAsFixed(2)}'
                        '  ·  net \$${net.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${pm['method'] ?? '—'} · ${pm['name'] ?? ''} · ${pm['address'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _process(id, 'approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _process(id, 'reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
