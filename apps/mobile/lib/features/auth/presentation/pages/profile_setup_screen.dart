import 'dart:async';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/features/auth/presentation/widgets/login_form_widgets.dart';
import 'package:sk_live/features/invite_earn/data/invite_earn_provider.dart';
import 'package:sk_live/core/services/auth_service.dart';

const _boyAvatar = 'assets/auth/boy.webp';
const _girlAvatar = 'assets/auth/girl.webp';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  String? _selectedGender;
  String? _selectedCountry;
  String? _selectedCountryCode;
  DateTime _dateOfBirth = DateTime(2007, 7, 1);
  final _usernameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  bool _isCheckingUsername = false;
  bool? _usernameAvailable;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCheckingUsername = true);
      final available = await AuthService.instance.isUsernameAvailable(
        username,
      );
      if (mounted) {
        setState(() {
          _usernameAvailable = available;
          _isCheckingUsername = false;
        });
      }
    });
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country.name;
          _selectedCountryCode = country.countryCode;
        });
      },
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.surface,
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        searchTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        inputDecoration: InputDecoration(
          hintText: context.l10n.auth_searchCountryHint,
          hintStyle: TextStyle(
            color: AppColors.textHint.withValues(alpha: 0.8),
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.primaryUltraLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _onComplete() async {
    if (_selectedGender == null ||
        _selectedCountryCode == null ||
        _usernameController.text.isEmpty) {
      _showSnack(context.l10n.auth_fillRequiredFields);
      return;
    }

    if (_usernameAvailable != true) {
      _showSnack(context.l10n.auth_chooseAvailableNickname);
      return;
    }

    final result = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          gender: _selectedGender!,
          countryCode: _selectedCountryCode!,
          username: _usernameController.text.trim(),
        );

    if (!mounted) return;

    if (result) {
      final inviteCode = _inviteCodeController.text.trim();
      if (inviteCode.isNotEmpty) {
        try {
          final inviteRes = await acceptInviteCode(inviteCode);
          if (mounted && inviteRes['success'] != true) {
            final msg = inviteRes['message']?.toString();
            if (msg != null && msg.isNotEmpty) {
              _showSnack(msg, isError: true);
            }
          } else if (mounted && inviteRes['success'] == true) {
            _showSnack(context.l10n.auth_invitationBonusApplied);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      context.go('/home');
    } else {
      final error = ref.read(authControllerProvider);
      final message = error is AsyncError
          ? 'Error: ${error.error}'
          : context.l10n.auth_failedUpdateProfile;
      _showSnack(message, isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider) is AsyncLoading;
    final l10n = context.l10n;
    final selectLabel = l10n.auth_select;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    l10n.auth_completeProfileTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AvatarOption(
                        asset: _boyAvatar,
                        isSelected: _selectedGender == 'male',
                        onTap: () => setState(() => _selectedGender = 'male'),
                      ),
                      const SizedBox(width: 28),
                      _AvatarOption(
                        asset: _girlAvatar,
                        isSelected: _selectedGender == 'female',
                        onTap: () => setState(() => _selectedGender = 'female'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  LoginFieldLabel(l10n.auth_nickname),
                  LoginPillTextField(
                    controller: _usernameController,
                    hintText: l10n.auth_hintEnter,
                    suffixIcon: _buildUsernameSuffix(),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.auth_basicInformation,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoSelectorRow(
                    label: l10n.auth_dateOfBirth,
                    value: DateFormat('yyyy-MM-dd').format(_dateOfBirth),
                    onTap: _pickDateOfBirth,
                  ),
                  const SizedBox(height: 12),
                  _InfoSelectorRow(
                    label: l10n.auth_countryRegion,
                    value: _selectedCountry ?? selectLabel,
                    isPlaceholder: _selectedCountry == null,
                    leading: _selectedCountryCode != null
                        ? Text(
                            Country.parse(_selectedCountryCode!).flagEmoji,
                            style: const TextStyle(fontSize: 18),
                          )
                        : null,
                    onTap: _pickCountry,
                  ),
                  const SizedBox(height: 28),
                  LoginFieldLabel(l10n.auth_invitationCodeOptional),
                  LoginPillTextField(
                    controller: _inviteCodeController,
                    hintText: l10n.auth_friendShortIdHint,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 40),
                  LoginPrimaryButton(
                    label: l10n.auth_go,
                    useAccent: true,
                    onPressed: isLoading ? null : _onComplete,
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildUsernameSuffix() {
    if (!_isCheckingUsername && _usernameAvailable == null) return null;
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }
    if (_usernameAvailable == true) {
      return const Icon(Icons.check_circle_rounded, color: AppColors.success);
    }
    return const Icon(Icons.error_outline_rounded, color: AppColors.error);
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  final String asset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
          ),
          if (isSelected)
            PositionedDirectional(
              end: 2,
              bottom: 2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoSelectorRow extends StatelessWidget {
  const _InfoSelectorRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.isPlaceholder = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: isPlaceholder
                          ? AppColors.textHint
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
