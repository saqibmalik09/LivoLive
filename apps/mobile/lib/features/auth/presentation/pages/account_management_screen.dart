import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  ConsumerState<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState
    extends ConsumerState<AccountManagementScreen> {
  static const _pageBg = Color(0xFFF5F5F5);
  static const _titleColor = Color(0xFF1A1A2E);
  static const _logoutPink = Color(0xFFFF2D78);

  String _versionLabel = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(
        () => _versionLabel = context.l10n.auth_versionLabel(info.version),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = context.l10n.auth_versionLabel('1.1.6'));
    }
  }

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _email {
    final u = _user;
    if (u == null) return '';
    final email = (u.email ?? '').trim();
    if (email.isNotEmpty) return email;
    for (final id in u.identities ?? const <UserIdentity>[]) {
      final e = id.identityData?['email']?.toString().trim();
      if (e != null && e.isNotEmpty) return e;
    }
    return '';
  }

  bool get _hasGoogle {
    final identities = _user?.identities ?? const <UserIdentity>[];
    return identities.any((i) => i.provider == 'google');
  }

  bool get _hasEmailProvider {
    final identities = _user?.identities ?? const <UserIdentity>[];
    if (identities.any((i) => i.provider == 'email')) return true;
    return (_user?.email ?? '').trim().isNotEmpty;
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;
    final local = parts[0];
    final domain = parts[1];
    final head = local.length >= 2 ? local.substring(0, 2) : local;
    final tail = local.length > 3 ? local[local.length - 1] : '';
    final domainHead = domain.isNotEmpty ? domain[0] : '';
    return '$head***$tail@$domainHead...';
  }

  Future<void> _confirmLogout() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.auth_logout),
        content: Text(l10n.auth_logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.auth_logout),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _openSetPassword() async {
    final email = _email;
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.auth_bindEmailFirst)));
      return;
    }

    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _SetPasswordSheet(maskedEmail: _maskEmail(email), email: email),
    );

    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auth_passwordUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AuthService.mapAuthError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAccountCancellation() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.auth_accountCancellation),
        content: Text(l10n.auth_cancellationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.auth_requestCancellation),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final user = _user;
      if (user == null) throw Exception('Not signed in');
      await Supabase.instance.client.from('support_messages').insert({
        'user_id': user.id,
        'subject': 'Account Cancellation',
        'message':
            'User requested account cancellation from Account Management.\nEmail: ${_email.isEmpty ? '(none)' : _email}',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.auth_cancellationSubmitted)),
      );
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit request: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAbout() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.auth_aboutSkLive),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LIVO', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.auth_versionLabel('${info.version} (${info.buildNumber})'),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.auth_aboutBlurb,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.common_ok),
          ),
        ],
      ),
    );
  }

  void _onBindingTap({required bool isGoogle}) {
    final email = _email;
    final bound = isGoogle ? _hasGoogle : _hasEmailProvider;
    final label = isGoogle ? context.l10n.auth_google : context.l10n.auth_email;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(
          bound
              ? (email.isEmpty
                    ? '$label is linked to this account.'
                    : '$label is linked:\n${_maskEmail(email)}')
              : '$label is not linked yet. Sign in with $label on the login screen to bind it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.common_ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = _email;
    final masked = email.isEmpty ? l10n.auth_notBound : _maskEmail(email);
    final googleTrailing = _hasGoogle ? masked : l10n.auth_notBound;
    final emailTrailing = _hasEmailProvider ? masked : l10n.auth_notBound;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: _titleColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.profile_settings,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _SectionLabel(l10n.auth_sectionAccountBinding),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          leading: Image.asset(
                            'assets/auth/google.webp',
                            width: 28,
                            height: 28,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 28,
                              color: _titleColor,
                            ),
                          ),
                          title: l10n.auth_google,
                          trailingText: googleTrailing,
                          onTap: () => _onBindingTap(isGoogle: true),
                        ),
                        _SettingsRow(
                          leading: const Icon(
                            Iconsax.sms,
                            size: 24,
                            color: _titleColor,
                          ),
                          title: l10n.auth_email,
                          trailingText: emailTrailing,
                          onTap: () => _onBindingTap(isGoogle: false),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.auth_sectionAccountManagement),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          leading: const Icon(
                            Iconsax.key,
                            size: 24,
                            color: _titleColor,
                          ),
                          title: l10n.auth_setPassword,
                          onTap: _busy ? null : _openSetPassword,
                        ),
                        _SettingsRow(
                          leading: const Icon(
                            Iconsax.logout,
                            size: 24,
                            color: _titleColor,
                          ),
                          title: l10n.auth_accountCancellation,
                          onTap: _busy ? null : _openAccountCancellation,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.auth_sectionOther),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/branding/app_logo.webp',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFB300),
                                      Color(0xFFFF2D78),
                                    ],
                                  ),
                                ),
                                child: const Text(
                                  'SK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: l10n.auth_aboutSkLive,
                          trailingText: _versionLabel.isEmpty
                              ? null
                              : _versionLabel,
                          onTap: _openAbout,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _confirmLogout,
                      style: FilledButton.styleFrom(
                        backgroundColor: _logoutPink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _logoutPink.withValues(
                          alpha: 0.5,
                        ),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.auth_logout,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(
                  child: CircularProgressIndicator(color: _logoutPink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.leading,
    required this.title,
    this.trailingText,
    this.onTap,
    this.showDivider = true,
  });

  final Widget leading;
  final String title;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(width: 32, height: 32, child: Center(child: leading)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailingText != null && trailingText!.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      trailingText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  Iconsax.arrow_right_3,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 60, color: Colors.grey.shade200),
      ],
    );
  }
}

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet({required this.maskedEmail, required this.email});

  final String maskedEmail;
  final String email;

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  static const _titleColor = Color(0xFF1A1A2E);
  static const _logoutPink = Color(0xFFFF2D78);

  final _formKey = GlobalKey<FormState>();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _sendingReset = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_sendingReset) return;
    setState(() => _sendingReset = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.resetPasswordForEmail(widget.email);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.auth_passwordResetSent)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.mapAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.auth_setPassword,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set a password for ${widget.maskedEmail} so you can log in with email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.auth_newPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return l10n.auth_passwordMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.auth_confirmPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v != _newCtrl.text) return l10n.auth_passwordsDoNotMatch;
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() != true) return;
                  Navigator.pop(context, _newCtrl.text);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _logoutPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  l10n.auth_savePassword,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _sendingReset ? null : _sendResetLink,
                child: _sendingReset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.auth_sendResetLinkInstead),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
