import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/wallet/providers/wallet_records_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class WalletRecordScreen extends ConsumerStatefulWidget {
  const WalletRecordScreen({super.key});

  @override
  ConsumerState<WalletRecordScreen> createState() => _WalletRecordScreenState();
}

class _WalletRecordScreenState extends ConsumerState<WalletRecordScreen>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF4C8DFF);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          'Wallet Record',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _blue.withValues(alpha: 0.5)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: _blue,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Coins'),
                  Tab(text: 'Diamonds'),
                  Tab(text: 'Balance'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _RecordsList(currency: WalletRecordCurrency.coins),
                _RecordsList(currency: WalletRecordCurrency.diamonds),
                _RecordsList(currency: WalletRecordCurrency.balance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsList extends ConsumerWidget {
  const _RecordsList({required this.currency});

  final WalletRecordCurrency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletRecordsProvider(currency));

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4C8DFF)),
      ),
      error: (e, _) => asyncErrorWidget(e),
      data: (records) {
        if (records.isEmpty) {
          return const Center(
            child: Text(
              'No more records',
              style: TextStyle(color: Colors.black45),
            ),
          );
        }

        final grouped = <String, List<WalletRecord>>{};
        for (final r in records) {
          final key = DateFormat('yyyy-MM').format(r.createdAt.toLocal());
          grouped.putIfAbsent(key, () => []).add(r);
        }
        final months = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 32),
          itemCount: months.length + 1,
          itemBuilder: (context, index) {
            if (index == months.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No more records',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                  ),
                ),
              );
            }
            final month = months[index];
            final items = grouped[month]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF3F3F5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    month,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                ...items.map((r) => _RecordTile(record: r, currency: currency)),
              ],
            );
          },
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.currency});

  final WalletRecord record;
  final WalletRecordCurrency currency;

  @override
  Widget build(BuildContext context) {
    final amountText = currency == WalletRecordCurrency.balance
        ? record.amount.toStringAsFixed(
            record.amount.truncateToDouble() == record.amount ? 0 : 2,
          )
        : NumberFormatter.format(record.amount.toInt());
    final sign = record.isCredit ? '+ ' : '- ';
    final color = record.isCredit
        ? const Color(0xFFE53935)
        : const Color(0xFF2E7D32);
    final time = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(record.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.subtitle,
                  style: const TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currency == WalletRecordCurrency.coins)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Iconsax.coin_1_copy,
                        size: 16,
                        color: Color(0xFFE6A800),
                      ),
                    )
                  else if (currency == WalletRecordCurrency.diamonds)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Iconsax.diamonds,
                        size: 16,
                        color: Color(0xFF5B7CFF),
                      ),
                    ),
                  Text(
                    '$sign$amountText',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(color: Colors.black38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
