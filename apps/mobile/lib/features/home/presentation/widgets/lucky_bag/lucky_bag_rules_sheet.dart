import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/lucky_bag_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/home/presentation/widgets/lucky_bag/lucky_bag_theme.dart';

class LuckyBagRulesSheet extends ConsumerWidget {
  const LuckyBagRulesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LuckyBagRulesSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(luckyBagRulesProvider);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        gradient: LuckyBagTheme.sheetGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
                    'Lucky Bag Rules',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: rulesAsync.when(
                data: (rules) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: ListView.separated(
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return Text(
                        '${index + 1}. ${rules[index]}',
                        style: const TextStyle(
                          color: AppColors.primaryDeep,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.textOnDark),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '$e',
                    style: const TextStyle(color: AppColors.textOnDark),
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
