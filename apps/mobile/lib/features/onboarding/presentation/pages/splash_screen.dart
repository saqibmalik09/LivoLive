import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    try {
      final authState = await ref.read(authStateProvider.future);
      final session = AuthService.instance.currentSession ?? authState.session;
      final loggedIn = session != null;

      if (!mounted) return;
      if (loggedIn) {
        context.go(AppRouter.home);
      } else {
        context.go(AppRouter.login);
      }
    } catch (e) {
      if (!mounted) return;
      if (AuthService.instance.currentSession != null) {
        context.go(AppRouter.home);
      } else {
        context.go(AppRouter.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/branding/app_logo.png',
                    width: 196,
                    height: 196,
                    fit: BoxFit.contain,
                  ),
                )
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack)
                .shimmer(
                  delay: 1.seconds,
                  duration: 2.seconds,
                  color: AppColors.gold.withOpacity(0.5),
                ),

            const SizedBox(height: 28),

            Text(
              context.l10n.splash_tagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
