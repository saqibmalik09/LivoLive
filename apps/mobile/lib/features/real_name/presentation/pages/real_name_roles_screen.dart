import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/features/real_name/data/real_name_provider.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_common.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_theme.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class RealNameRolesScreen extends ConsumerStatefulWidget {
  const RealNameRolesScreen({super.key});

  @override
  ConsumerState<RealNameRolesScreen> createState() =>
      _RealNameRolesScreenState();
}

class _RealNameRolesScreenState extends ConsumerState<RealNameRolesScreen> {
  String? _selectedId;
  bool _loading = false;

  Future<void> _confirm() async {
    if (_selectedId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a role')));
      return;
    }
    setState(() => _loading = true);
    final stepRes = await RealNameActions.upsertStep(
      step: 'step5_role',
      payload: {'role_package_id': _selectedId},
    );
    if (stepRes['success'] != true) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(stepRes['message']?.toString() ?? 'Failed')),
      );
      return;
    }

    final review = await RealNameActions.submitForReview();
    setState(() => _loading = false);
    if (!mounted) return;
    if (review['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(review['message']?.toString() ?? 'Failed')),
      );
      return;
    }
    ref.invalidate(realNameCenterProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Submitted for review')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(realNameCenterProvider);

    return Theme(
      data: RealNameTheme.light(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Pass the certification')),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => asyncErrorWidget(e),
          data: (state) {
            if (state == null) return const SizedBox.shrink();
            final packages = state.rolePackages;
            _selectedId ??=
                state.application.rolePackageId ??
                (packages.isNotEmpty ? packages.first.id : null);
            final locked =
                state.application.status == 'pending' ||
                state.application.status == 'approved';

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const Text(
                        'Select the role you are applying for. After confirmation your application will be sent for admin review.',
                        style: TextStyle(
                          color: RealNameTheme.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...packages.map((p) {
                        final selected = _selectedId == p.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: locked
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
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: RealNamePrimaryButton(
                      label: locked ? 'Submitted' : 'Confirm',
                      loading: _loading,
                      onPressed: locked ? null : _confirm,
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
