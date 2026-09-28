import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/auth/presentation/widgets/login_form_widgets.dart';
import 'package:sk_live/core/services/auth_service.dart';

class IdLoginScreen extends ConsumerStatefulWidget {
  const IdLoginScreen({super.key});

  @override
  ConsumerState<IdLoginScreen> createState() => _IdLoginScreenState();
}

class _IdLoginScreenState extends ConsumerState<IdLoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  Future<void> _loginWithPassword() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;

    if (id.isEmpty) {
      _showMessage(context.l10n.auth_enterId);
      return;
    }
    if (!_isEmail(id)) {
      _showMessage('For phone login, use "Login with verification code"');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: id, password: password);
    if (!mounted) return;
    if (success) return;

    final authState = ref.read(authControllerProvider);
    final message = authState is AsyncError
        ? authState.error.toString()
        : 'Login failed. Please try again.';
    _showMessage(message);
  }

  Future<void> _loginWithVerificationCode() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _showMessage('Please enter your phone number');
      return;
    }
    if (_isEmail(id)) {
      _showMessage('Use email login for email accounts');
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).sendOtp(id);
    if (success && mounted) {
      context.push(AppRouter.otp, extra: id);
    } else if (mounted) {
      final authState = ref.read(authControllerProvider);
      final message = authState is AsyncError
          ? AuthService.mapAuthError(authState.error)
          : 'Could not send verification code';
      _showMessage(message);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider) is AsyncLoading;

    return LoginFormScaffold(
      isLoading: isLoading,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const LoginFieldLabel('ID'),
          LoginPillTextField(
            controller: _idController,
            hintText: 'Enter phone or email',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 20),
          LoginFieldLabel(
            'Password',
            trailing: TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      final id = _idController.text.trim();
                      if (_isEmail(id)) {
                        context.push(AppRouter.emailPasswordLogin, extra: id);
                      } else {
                        _showMessage(
                          'Enter your email in ID field for password reset',
                        );
                      }
                    },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.accent,
              ),
              child: Text(
                context.l10n.auth_forgotPassword,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          LoginPillTextField(
            controller: _passwordController,
            hintText: 'Enter',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textHint,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            onSubmitted: (_) => _loginWithPassword(),
          ),
          const SizedBox(height: 28),
          LoginPrimaryButton(
            label: 'Login',
            useAccent: true,
            onPressed: isLoading ? null : _loginWithPassword,
          ),
          const LoginOrDivider(),
          LoginOutlineButton(
            label: context.l10n.auth_loginWithCode,
            onPressed: isLoading ? null : _loginWithVerificationCode,
          ),
        ],
      ),
    );
  }
}
