import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/real_name/data/real_name_provider.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_common.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_theme.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class RealNameDepositScreen extends ConsumerStatefulWidget {
  const RealNameDepositScreen({super.key});

  @override
  ConsumerState<RealNameDepositScreen> createState() =>
      _RealNameDepositScreenState();
}

class _RealNameDepositScreenState extends ConsumerState<RealNameDepositScreen> {
  String? _selectedId;
  bool _loading = false;

  Future<void> _confirm() async {
    if (_selectedId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a deposit package')));
      return;
    }
    setState(() => _loading = true);
    final res = await RealNameActions.submitDeposit(_selectedId!);
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Failed')),
      );
      return;
    }
    final review = await RealNameActions.submitForReview();
    ref.invalidate(realNameCenterProvider);
    if (!mounted) return;
    final reviewOk = review['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reviewOk
              ? 'Security deposit paid — submitted for review'
              : (review['message']?.toString() ??
                    'Security deposit paid — complete remaining steps to submit'),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(realNameCenterProvider);

    return Theme(
      data: RealNameTheme.light(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Security Deposit')),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => asyncErrorWidget(e),
          data: (state) {
            if (state == null) return const SizedBox.shrink();
            final paid = state.application.step4Done;
            final packages = state.depositPackages;
            _selectedId ??=
                state.application.depositPackageId ??
                (packages.isNotEmpty ? packages.first.id : null);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFD6E8FF), Color(0xFFEAF3FF)],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Instructions on Security Deposit',
                                    style: TextStyle(
                                      color: RealNameTheme.primaryDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'A security deposit helps maintain platform service quality. It may be refundable after a 30-day review period.',
                                    style: TextStyle(
                                      color: RealNameTheme.textMuted,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Iconsax.coin,
                              size: 48,
                              color: Color(0xFFFBBF24),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Security Deposit: ${NumberFormatter.format(state.application.depositCoins ?? 0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            const Text(
                              'My Coin: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Icon(
                              Iconsax.coin,
                              color: Color(0xFFFBBF24),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              NumberFormatter.format(state.coins),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...packages.map((p) {
                        final selected = _selectedId == p.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: paid
                                  ? null
                                  : () => setState(() => _selectedId = p.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? RealNameTheme.primary
                                        : RealNameTheme.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Iconsax.coin,
                                      color: Color(0xFFFBBF24),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      NumberFormatter.format(p.priceCoins),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: RealNamePrimaryButton(
                      label: paid ? 'Already Paid' : 'Confirm',
                      loading: _loading,
                      onPressed: paid ? null : _confirm,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
