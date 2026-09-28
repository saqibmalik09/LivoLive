import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/real_name/data/real_name_provider.dart';
import 'package:sk_live/features/real_name/presentation/pages/real_name_deposit_screen.dart';
import 'package:sk_live/features/real_name/presentation/pages/real_name_identity_screen.dart';
import 'package:sk_live/features/real_name/presentation/pages/real_name_personal_info_screen.dart';
import 'package:sk_live/features/real_name/presentation/pages/real_name_video_screen.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_theme.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class RealNameGuidelinesScreen extends ConsumerWidget {
  const RealNameGuidelinesScreen({super.key});

  static const _steps = <(String, String)>[
    ('STEP1', 'Personal information'),
    ('STEP2', 'Identity information authentication'),
    ('STEP3', 'Scheduled video authentication'),
    ('STEP4', 'Security deposit'),
    ('STEP5', 'Pass the certification'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(realNameCenterProvider);

    return Theme(
      data: RealNameTheme.light(context),
      child: Scaffold(
        backgroundColor: RealNameTheme.bg,
        appBar: AppBar(title: Text(context.l10n.realName_guidelines)),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => asyncErrorWidget(e),
          data: (state) {
            if (state == null) {
              return const Center(child: Text('Unable to load application'));
            }
            final app = state.application;
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(realNameCenterProvider),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDCEBFF), Color(0xFFEAF2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Real Name\nVerification',
                            style: TextStyle(
                              color: RealNameTheme.primaryDark,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              height: 1.15,
                            ),
                          ),
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: RealNameTheme.primary,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: RealNameTheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Iconsax.shield_tick,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.status == 'pending')
                    _statusBanner(
                      'Under review — please wait for admin approval.',
                      RealNameTheme.primary,
                    ),
                  if (app.status == 'approved')
                    _statusBanner(
                      'Approved — certification complete.',
                      RealNameTheme.success,
                    ),
                  if (app.status == 'rejected')
                    _statusBanner(
                      'Rejected: ${app.rejectReason ?? 'Please resubmit.'}',
                      RealNameTheme.fail,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      children: List.generate(_steps.length, (i) {
                        final step = i + 1;
                        final done = app.stepDone(step);
                        final unlocked = app.status != 'approved';
                        return _StepRow(
                          label: _steps[i].$1,
                          title: _steps[i].$2,
                          done: done,
                          isLast: i == _steps.length - 1,
                          onTap: () {
                            if (step == 5) {
                              final msg = switch (app.status) {
                                'approved' => 'Certification passed',
                                'pending' =>
                                  'Under review — waiting for admin approval',
                                'rejected' =>
                                  app.rejectReason ??
                                      'Rejected — please update earlier steps and resubmit',
                                _ =>
                                  'Complete steps 1–4; certification tick appears after admin approval',
                              };
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                              return;
                            }
                            if (!unlocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Application already approved'),
                                ),
                              );
                              return;
                            }
                            _openStep(context, ref, step);
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusBanner(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Future<void> _openStep(BuildContext context, WidgetRef ref, int step) async {
    final Widget page;
    switch (step) {
      case 1:
        page = const RealNamePersonalInfoScreen();
        break;
      case 2:
        page = const RealNameIdentityScreen();
        break;
      case 3:
        page = const RealNameVideoScreen();
        break;
      case 4:
        page = const RealNameDepositScreen();
        break;
      default:
        return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    ref.invalidate(realNameCenterProvider);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.title,
    required this.done,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final String title;
  final bool done;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: RealNameTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 1,
                    shadowColor: Colors.black12,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: RealNameTheme.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              done ? Icons.check_circle : Icons.cancel,
                              color: done
                                  ? RealNameTheme.success
                                  : RealNameTheme.fail,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
