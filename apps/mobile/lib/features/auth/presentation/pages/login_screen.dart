import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/widgets/animated_background.dart';

const _privacyPolicyUrl = 'https://rave-land.vercel.app/privacy';
const _termsOfServiceUrl = 'https://rave-land.vercel.app/terms';
const _emailIconAsset = 'assets/auth/email.webp';
const _idIconAsset = 'assets/auth/id.webp';
const _googleIconAsset = 'assets/auth/google.webp';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _privacySectionKey = GlobalKey();
  bool _privacyAccepted = false;
  bool _highlightPrivacy = false;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  void _scrollToPrivacySection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _privacySectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.9,
        );
      }
    });
  }

  bool _ensurePrivacyAccepted() {
    if (_privacyAccepted) {
      if (_highlightPrivacy) setState(() => _highlightPrivacy = false);
      return true;
    }
    setState(() => _highlightPrivacy = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.auth_acceptTermsSnack),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
    _scrollToPrivacySection();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) {
          if (!mounted) return;
          final msg = err.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 6),
            ),
          );
        },
      );
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBackground(
            images: [
              'assets/auth/login_slide_1.jpg',
              'assets/auth/login_slide_2.webp',
              'assets/auth/login_slide_3.webp',
            ],
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 24, 32, 16 + bottomInset),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const Text(
                    'LIVO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.15),
                  const Spacer(flex: 2),
                  _buildGoogleButton(isLoading),
                  const SizedBox(height: 28),
                  Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCircleLoginIcon(
                            asset: _emailIconAsset,
                            onTap: isLoading
                                ? null
                                : () {
                                    if (!_ensurePrivacyAccepted()) return;
                                    context.push(AppRouter.emailLogin);
                                  },
                          ),
                          const SizedBox(width: 36),
                          _buildCircleLoginIcon(
                            asset: _idIconAsset,
                            onTap: isLoading
                                ? null
                                : () {
                                    if (!_ensurePrivacyAccepted()) return;
                                    context.push(AppRouter.idLogin);
                                  },
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .scale(begin: const Offset(0.92, 0.92)),
                  const Spacer(flex: 3),
                  _buildPrivacyFooter(),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Lottie.asset(
                  'assets/effects/simple_loading.json',
                  width: 220,
                  height: 220,
                  errorBuilder: (context, error, stackTrace) {
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                if (!_ensurePrivacyAccepted()) return;
                ref.read(authControllerProvider.notifier).signInWithGoogle();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              _googleIconAsset,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.auth_continueWithGoogle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08);
  }

  Widget _buildCircleLoginIcon({
    required String asset,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyFooter() {
    final l10n = context.l10n;
    return KeyedSubtree(
      key: _privacySectionKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _highlightPrivacy
              ? Border.all(color: Colors.redAccent, width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _privacyAccepted = !_privacyAccepted;
                if (_privacyAccepted) _highlightPrivacy = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _privacyAccepted
                      ? AppColors.accent
                      : Colors.transparent,
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: _privacyAccepted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: l10n.auth_agreePrefix,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    height: 1.45,
                  ),
                  children: [
                    TextSpan(
                      text: l10n.auth_termsOfService,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openUrl(_termsOfServiceUrl),
                    ),
                    TextSpan(text: l10n.auth_and),
                    TextSpan(
                      text: l10n.auth_privacyPolicy,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openUrl(_privacyPolicyUrl),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
