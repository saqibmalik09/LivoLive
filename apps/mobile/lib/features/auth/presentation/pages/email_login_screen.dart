import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:sk_live/features/auth/presentation/widgets/login_form_widgets.dart';

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  void _onNext() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email address');
      return;
    }
    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address');
      return;
    }
    context.push(AppRouter.emailPasswordLogin, extra: email);
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
          const LoginFieldLabel('Please enter your email address'),
          LoginPillTextField(
            controller: _emailController,
            hintText: 'Enter',
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _onNext(),
          ),
          const SizedBox(height: 28),
          LoginPrimaryButton(
            label: 'Next',
            useAccent: true,
            onPressed: isLoading ? null : _onNext,
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
