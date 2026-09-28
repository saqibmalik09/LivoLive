import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/lucky_bag_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_rules_sheet.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_record_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_theme.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

const _luckyBagCoinAssets = [
  'assets/rewards/lucky-bag/coin-1.webp',
  'assets/rewards/lucky-bag/coin-2.webp',
  'assets/rewards/lucky-bag/coin-3.webp',
  'assets/rewards/lucky-bag/coin-4.webp',
];

String _coinAssetForTierIndex(int index) {
  return _luckyBagCoinAssets[index.clamp(0, _luckyBagCoinAssets.length - 1)];
}

class LuckyBagSheet extends ConsumerStatefulWidget {
  const LuckyBagSheet({super.key, required this.roomId});

  final String roomId;

  static Future<void> show(BuildContext context, {required String roomId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LuckyBagSheet(roomId: roomId),
    );
  }

  @override
  ConsumerState<LuckyBagSheet> createState() => _LuckyBagSheetState();
}

class _LuckyBagSheetState extends ConsumerState<LuckyBagSheet> {
  int _tabIndex = 0;
  LuckyBagTier? _selectedTier;
  int? _selectedRecipients;
  bool _sending = false;

  String get _scope => _tabIndex == 0 ? 'room' : 'world';

  Future<void> _send() async {
    final tiers = ref.read(luckyBagTiersProvider).valueOrNull;
    if (tiers == null || tiers.isEmpty || _sending) return;

    final tier = _selectedTier ?? tiers.first;
    final recipientCount = _selectedRecipients ?? tier.recipientOptions.first;

    setState(() => _sending = true);
    try {
      final result = await LuckyBagService.createBag(
        roomId: widget.roomId,
        scope: _scope,
        tierId: tier.id,
        recipientCount: recipientCount,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ref.invalidate(userProfileProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_scope == 'room' ? 'Room' : 'World'} lucky bag sent!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to send'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(luckyBagTiersProvider);
    final coins =
        (ref.watch(userProfileProvider).valueOrNull?['coins'] as num?)
            ?.toInt() ??
        0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LuckyBagTheme.sheetGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => LuckyBagRulesSheet.show(context),
                  icon: const Icon(
                    Iconsax.info_circle,
                    color: AppColors.textOnDark,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _TabChip(
                        label: context.l10n.room_luckyBagTitle,
                        selected: _tabIndex == 0,
                        onTap: () => setState(() => _tabIndex = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabChip(
                        label: 'World Lucky Bag',
                        selected: _tabIndex == 1,
                        onTap: () => setState(() => _tabIndex = 1),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const LuckyBagRecordScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Iconsax.document_text,
                    color: AppColors.textOnDark,
                  ),
                ),
              ],
            ),
          ),
          tiersAsync.when(
            data: (tiers) {
              if (tiers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No lucky bag tiers configured.',
                    style: TextStyle(color: AppColors.textOnDark),
                  ),
                );
              }
              final tier = _selectedTier ?? tiers.first;
              final recipients = tier.recipientOptions;
              final recipientsSelected =
                  _selectedRecipients ?? tier.recipientOptions.first;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.room_luckyBagValue,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 10,
                            childAspectRatio: 3.2,
                          ),
                      itemCount: tiers.length,
                      itemBuilder: (context, index) {
                        final item = tiers[index];
                        final selected = tier.id == item.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedTier = item;
                            if (_selectedRecipients == null ||
                                !item.recipientOptions.contains(
                                  _selectedRecipients,
                                )) {
                              _selectedRecipients = item.recipientOptions.first;
                            }
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: selected
                                    ? [
                                        Colors.white,
                                        AppColors.primaryUltraLight,
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.72),
                                        Colors.white.withValues(alpha: 0.52),
                                      ],
                              ),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.85),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    _coinAssetForTierIndex(index),
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: selected
                                          ? AppColors.primaryDark
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Number of recipients',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: recipients.map((count) {
                        final selected = recipientsSelected == count;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedRecipients = count),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.32),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? AppColors.primaryDark
                                        : AppColors.textOnDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LuckyBagTheme.sendGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: LuckyBagTheme.sendShadow,
                        ),
                        child: ElevatedButton(
                          onPressed: _sending ? null : _send,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.primaryDeep,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryDeep,
                                  ),
                                )
                              : const Text(
                                  'Send',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          _luckyBagCoinAssets.first,
                          width: 22,
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.textOnDark),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Error: $e',
                style: const TextStyle(color: AppColors.textOnDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected ? LuckyBagTheme.tabSelectedGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : AppColors.textOnDark.withValues(alpha: 0.55),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? LuckyBagTheme.tabShadow : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textOnDark,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
