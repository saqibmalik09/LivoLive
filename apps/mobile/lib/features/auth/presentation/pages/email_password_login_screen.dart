import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/auth/presentation/widgets/login_form_widgets.dart';
import 'package:sk_live/core/services/auth_service.dart';

class EmailPasswordLoginScreen extends ConsumerStatefulWidget {
  const EmailPasswordLoginScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailPasswordLoginScreen> createState() =>
      _EmailPasswordLoginScreenState();
}

class _EmailPasswordLoginScreenState
    extends ConsumerState<EmailPasswordLoginScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSignUp = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }

    final notifier = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      final result = await notifier.signUpWithEmail(
        email: widget.email,
        password: password,
      );
      if (!mounted) return;
      if (result.success && result.needsEmailConfirmation) {
        _showMessage(context.l10n.auth_checkEmailConfirm, success: true);
        context.go(AppRouter.login);
        return;
      }
      if (result.success) return;
    } else {
      final success = await notifier.signInWithEmail(
        email: widget.email,
        password: password,
      );
      if (!mounted) return;
      if (success) return;
    }

    final authState = ref.read(authControllerProvider);
    final message = authState is AsyncError
        ? authState.error.toString()
        : 'Authentication failed. Please try again.';
    _showMessage(message);
  }

  Future<void> _forgotPassword() async {
    try {
      await AuthService.instance.resetPasswordForEmail(widget.email);
      if (!mounted) return;
      _showMessage(
        'Password reset link sent to ${widget.email}',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(AuthService.mapAuthError(e));
    }
  }

  void _showMessage(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
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
          LoginFieldLabel(
            'Password',
            trailing: TextButton(
              onPressed: isLoading ? null : _forgotPassword,
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
            onSubmitted: (_) => _submit(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.email,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 28),
          LoginPrimaryButton(
            label: _isSignUp ? 'Sign up' : 'Login',
            useAccent: true,
            onPressed: isLoading ? null : _submit,
          ),
          TextButton(
            onPressed: isLoading
                ? null
                : () => setState(() => _isSignUp = !_isSignUp),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Log in'
                  : "Don't have an account? Sign up",
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const LoginOrDivider(),
          LoginGoogleButton(
            onPressed: isLoading
                ? null
                : () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle(),
          ),
        ],
      ),
    );
  }
}
