import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';

/// Branded frame shown only while the local session probe is in flight.
/// The router sends `/` to home or login; this screen does not wait on
/// auth, Supabase, or the network.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
                  color: AppColors.gold.withValues(alpha: 0.5),
                ),

            const SizedBox(height: 28),

            Text(
              context.l10n.splash_tagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
