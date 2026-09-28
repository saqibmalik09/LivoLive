import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/wallet/providers/withdraw_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class BillRecordsScreen extends ConsumerStatefulWidget {
  const BillRecordsScreen({super.key});

  @override
  ConsumerState<BillRecordsScreen> createState() => _BillRecordsScreenState();
}

class _BillRecordsScreenState extends ConsumerState<BillRecordsScreen> {
  static const _purple = Color(0xFF7E69FF);
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDay = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billRecordsProvider(_selectedDay));
    final dateLabel = DateFormat('yyyy-MM-dd').format(_selectedDay);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bill',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 20,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
                ],
              ),
            ),
          ),
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _purple),
              ),
              error: (e, _) => asyncErrorWidget(e),
              data: (bills) {
                if (bills.isEmpty) {
                  return const Center(
                    child: Text(
                      'No bill records',
                      style: TextStyle(color: Colors.black45, fontSize: 15),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: bills.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final b = bills[i];
                    final amount = (b['amount'] as num?)?.toDouble() ?? 0;
                    final fee = (b['fee'] as num?)?.toDouble() ?? 0;
                    final net = (b['net_amount'] as num?)?.toDouble() ?? 0;
                    final status = b['status']?.toString() ?? '';
                    final statusLabel = switch (status) {
                      'pending' => 'Pending',
                      'reseller_approved' =>
                        context.l10n.reseller_approvedWaiting,
                      'approved' => 'Approved',
                      'rejected' => 'Rejected',
                      'completed' => 'Completed',
                      'cancelled' => 'Cancelled',
                      _ => status,
                    };
                    final targetType = b['target_type']?.toString() ?? '';
                    final target = b['target'] as Map<String, dynamic>?;
                    final created =
                        DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                        DateTime.now();
                    final timeLabel = DateFormat(
                      'yyyy-MM-dd HH:mm:ss',
                    ).format(created.toLocal());

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Withdraw · ${targetType == 'reseller'
                                      ? 'Coin Reseller'
                                      : targetType == 'official'
                                      ? 'Official'
                                      : 'Agent'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  target != null
                                      ? '${target['username']} · $statusLabel'
                                      : statusLabel,
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 13,
                                  ),
                                ),
                                if (fee > 0)
                                  Text(
                                    'Fee \$${fee.toStringAsFixed(2)} · Net \$${net.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.black38,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '- \$${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFE53935),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
