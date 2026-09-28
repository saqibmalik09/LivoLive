import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/lucky_bag_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_theme.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

const _coinAsset = 'assets/rewards/lucky-bag/coin-1.webp';

class LuckyBagRecordScreen extends ConsumerStatefulWidget {
  const LuckyBagRecordScreen({super.key});

  @override
  ConsumerState<LuckyBagRecordScreen> createState() =>
      _LuckyBagRecordScreenState();
}

class _LuckyBagRecordScreenState extends ConsumerState<LuckyBagRecordScreen> {
  int _tabIndex = 0;

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LuckyBagTheme.headerGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Iconsax.arrow_left,
                            color: AppColors.textOnDark,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Lucky Bag Record',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textOnDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _RecordTabBar(
                      selectedIndex: _tabIndex,
                      onChanged: (index) => setState(() => _tabIndex = index),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _tabIndex == 0
                ? _ReceivedList(formatDate: _formatDate)
                : _IssuedList(formatDate: _formatDate),
          ),
        ],
      ),
    );
  }
}

class _RecordTabBar extends StatelessWidget {
  const _RecordTabBar({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.textOnDark.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _tab(label: 'Received', index: 0),
          _tab(label: 'Issued', index: 1),
        ],
      ),
    );
  }

  Expanded _tab({required String label, required int index}) {
    final selected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? LuckyBagTheme.tabSelectedGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected ? LuckyBagTheme.tabShadow : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textOnDark,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceivedList extends ConsumerWidget {
  const _ReceivedList({required this.formatDate});

  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(luckyBagReceivedHistoryProvider);

    return async.when(
      data: (items) {
        if (items.isEmpty) return const _EmptyRecords();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _RecordCard(
              coinAmount: item.coins,
              title: 'From ${item.senderName ?? 'User'}',
              subtitle: '${item.scope == 'world' ? 'World' : 'Room'} lucky bag',
              date: formatDate(item.claimedAt),
              amountColor: AppColors.success,
              prefix: '+',
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _IssuedList extends ConsumerWidget {
  const _IssuedList({required this.formatDate});

  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(luckyBagIssuedHistoryProvider);

    return async.when(
      data: (items) {
        if (items.isEmpty) return const _EmptyRecords();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final label = item.tierLabel ?? '${item.totalCoins}';
            return _RecordCard(
              coinAmount: item.totalCoins,
              title: '$label · ${item.recipientCount} recipients',
              subtitle:
                  '${item.scope == 'world' ? 'World' : 'Room'} · ${item.claimedCount}/${item.recipientCount} claimed · ${_statusLabel(item.status)}',
              date: formatDate(item.createdAt),
              amountColor: AppColors.primaryDark,
              prefix: '-',
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) =>
          asyncErrorWidget(e, style: const TextStyle(color: AppColors.error)),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'finished':
        return 'Finished';
      case 'expired':
        return 'Expired';
      default:
        return 'Active';
    }
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.coinAmount,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amountColor,
    required this.prefix,
  });

  final int coinAmount;
  final String title;
  final String subtitle;
  final String date;
  final Color amountColor;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LuckyBagTheme.tabSelectedGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(_coinAsset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$prefix$coinAmount',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(_coinAsset, width: 18, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.document_text,
            size: 56,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No records',
            style: TextStyle(color: AppColors.textHint, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
