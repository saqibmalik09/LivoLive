import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/providers/device_ban_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class AccountBannedScreen extends ConsumerWidget {
  const AccountBannedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final deviceBan = ref.watch(deviceBanProvider).value;

    final accountNote = (profile?['ban_reason']?.toString() ?? '').trim();
    final deviceNote = (deviceBan?.reason ?? '').trim();
    final note = accountNote.isNotEmpty ? accountNote : deviceNote;
    final deviceOnly = accountNote.isEmpty && (deviceBan?.isBanned == true);

    final loggedIn = ref.watch(authStateProvider).value?.session != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0A0A), Color(0xFF0B0B0F), Color(0xFF050508)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      size: 44,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    deviceOnly
                        ? context.l10n.auth_deviceSuspended
                        : context.l10n.auth_accountSuspended,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deviceOnly
                        ? (note.isNotEmpty
                              ? note
                              : 'This device has been banned by an administrator.')
                        : 'Your account has been banned by an administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (!deviceOnly && accountNote.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.auth_adminNote,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            accountNote,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(flex: 3),
                  if (loggedIn)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.l10n.auth_signOut,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
