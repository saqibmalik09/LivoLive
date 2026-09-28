import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/username_validator.dart';
import 'package:sk_live/core/services/auth_service.dart';
import 'package:sk_live/core/services/upload_service.dart';
import 'package:sk_live/core/widgets/profile_cover_carousel.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  bool _isUploadingAvatar = false;
  bool _isUploadingBanner = false;
  bool _isUploadingCover = false;
  bool _isSavingBio = false;

  List<String> _parseCoverImages(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    }
    return [];
  }

  DateTime? _parseBirthDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  Future<void> _handleUpload(bool isAvatar) async {
    setState(() {
      if (isAvatar) {
        _isUploadingAvatar = true;
      } else {
        _isUploadingBanner = true;
      }
    });

    final url = await UploadService.instance.pickAndUploadImage(
      isAvatar: isAvatar,
      context: context,
    );
    if (url != null) ref.invalidate(userProfileProvider);

    if (mounted) {
      setState(() {
        _isUploadingAvatar = false;
        _isUploadingBanner = false;
      });
    }
  }

  Future<void> _addCoverPhoto() async {
    setState(() => _isUploadingCover = true);
    final url = await UploadService.instance.pickAndUploadCoverPhoto(context);
    if (url != null) ref.invalidate(userProfileProvider);
    if (mounted) setState(() => _isUploadingCover = false);
  }

  Future<void> _removeCoverPhoto(String url) async {
    await UploadService.instance.removeCoverPhoto(url);
    ref.invalidate(userProfileProvider);
  }

  Future<void> _refreshProfile() async {
    ref.invalidate(userProfileProvider);
    await ref.read(userProfileProvider.future);
  }

  Future<void> _saveProfileField(
    Future<void> Function() save, {
    String? successMessage,
  }) async {
    try {
      await save();
      await _refreshProfile();
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _editName(String currentUsername) async {
    final userId = ref.read(userProfileProvider).value?['id']?.toString();
    final messenger = ScaffoldMessenger.of(context);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _EditNameDialog(currentUsername: currentUsername, userId: userId),
    );

    if (!mounted || newName == null) return;

    try {
      await AuthService.instance.updateProfile(username: newName);
      await _refreshProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.edit_nameUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickGender(String? current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.male, color: Colors.blue),
              title: Text(ctx.l10n.edit_male),
              onTap: () => Navigator.pop(ctx, 'male'),
              trailing: current == 'male'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.female, color: Colors.pink),
              title: Text(ctx.l10n.edit_female),
              onTap: () => Navigator.pop(ctx, 'female'),
              trailing: current == 'female'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current) return;
    await _saveProfileField(
      () => AuthService.instance.updateProfile(gender: selected),
      successMessage: 'Gender updated',
    );
  }

  Future<void> _pickBirthday(DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final formatted = DateFormat('yyyy-MM-dd').format(picked);
    final dobUpdatedMsg = context.l10n.edit_dobUpdated;
    await _saveProfileField(
      () => AuthService.instance.updateProfile(dateOfBirth: formatted),
      successMessage: dobUpdatedMsg,
    );
  }

  Future<void> _pickCountry(String? currentCode) async {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) async {
        if (country.countryCode == currentCode) return;
        await _saveProfileField(
          () => AuthService.instance.updateProfile(
            countryCode: country.countryCode,
          ),
          successMessage: 'Country updated',
        );
      },
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Future<void> _editAbout(String currentBio) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditAboutDialog(currentBio: currentBio),
    );
    if (result == null || !mounted) return;

    setState(() => _isSavingBio = true);
    try {
      await AuthService.instance.updateProfile(bio: result);
      await _refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingBio = false);
    }
  }

  String _genderLabel(String? gender) {
    if (gender == 'male') return context.l10n.edit_male;
    if (gender == 'female') return context.l10n.edit_female;
    return 'Select';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => asyncErrorWidget(e),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Profile not found'));
          }

          final bannerUrl = user['banner_url']?.toString();
          final avatarUrl = user['avatar_url']?.toString();
          final username = user['username']?.toString() ?? 'User';
          final gender = user['gender']?.toString();
          final countryCode = user['country_code']?.toString();
          final bio = user['bio']?.toString().trim() ?? '';
          final covers = _parseCoverImages(user['cover_images']);
          final birth = _parseBirthDate(user['date_of_birth']);
          final birthLabel = birth != null
              ? DateFormat('yyyy-MM-dd').format(birth)
              : 'Select';

          return Column(
            children: [
              _buildHeader(
                bannerUrl: bannerUrl,
                avatarUrl: avatarUrl,
                coverPhotos: covers,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                  children: [
                    _EditRow(
                      label: 'Name',
                      value: username,
                      onTap: () => _editName(username),
                    ),
                    _divider(),
                    _EditRow(
                      label: 'Gender',
                      value: _genderLabel(gender),
                      onTap: () => _pickGender(gender),
                    ),
                    _divider(),
                    _EditRow(
                      label: 'Date of Birth',
                      value: birthLabel,
                      onTap: () => _pickBirthday(birth),
                    ),
                    _divider(),
                    _EditRow(
                      label: 'Country / Region',
                      value: countryCode != null
                          ? Country.parse(countryCode).name
                          : 'Select',
                      leading: countryCode != null
                          ? Text(
                              Country.parse(countryCode).flagEmoji,
                              style: const TextStyle(fontSize: 18),
                            )
                          : null,
                      onTap: () => _pickCountry(countryCode),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Picture',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPictureRow(covers),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'About me',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isSavingBio
                              ? null
                              : () => _editAbout(bio),
                          icon: const Icon(Iconsax.edit_2, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _editAbout(bio),
                      child: Text(
                        bio.isEmpty ? 'Fill in your personal signature' : bio,
                        style: TextStyle(
                          fontSize: 14,
                          color: bio.isEmpty
                              ? AppColors.textHint
                              : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    String? bannerUrl,
    String? avatarUrl,
    required List<String> coverPhotos,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: GestureDetector(
            onTap: () => _handleUpload(false),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfileCoverCarousel(
                  imageUrls: coverPhotos,
                  fallbackUrl: bannerUrl,
                  height: 200,
                  dotsOverlay: true,
                  lightDots: true,
                  emptyPlaceholder: Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Iconsax.image,
                        color: Colors.white38,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                if (_isUploadingBanner)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    radius: 16,
                    child: const Icon(
                      Iconsax.camera,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          left: 4,
          right: 4,
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  context.l10n.edit_profileTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Positioned(
          left: 20,
          bottom: -44,
          child: GestureDetector(
            onTap: () => _handleUpload(true),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Iconsax.user, size: 36)
                        : (_isUploadingAvatar
                              ? const CircularProgressIndicator()
                              : null),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.black87,
                  child: const Icon(
                    Iconsax.camera,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPictureRow(List<String> covers) {
    return Row(
      children: List.generate(3, (index) {
        final hasImage = index < covers.length;
        final url = hasImage ? covers[index] : null;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
            child: AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onTap: hasImage
                    ? null
                    : (_isUploadingCover ? null : _addCoverPhoto),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(8),
                    image: hasImage
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(url!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? Stack(
                          children: [
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeCoverPhoto(url!),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : (_isUploadingCover
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Iconsax.add,
                                color: AppColors.textHint,
                                size: 28,
                              )),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6));
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, color: AppColors.textHint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.currentUsername, this.userId});

  final String currentUsername;
  final String? userId;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final newName = _controller.text.trim();
    if (newName == widget.currentUsername) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final available = await AuthService.instance.isUsernameAvailable(
        newName,
        excludeUserId: widget.userId,
      );
      if (!mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name is already taken'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      Navigator.pop(context, newName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_isLoading) _onSave();
          },
          decoration: const InputDecoration(
            hintText: 'Your display name',
            border: OutlineInputBorder(),
          ),
          validator: UsernameValidator.validate,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _onSave,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _EditAboutDialog extends StatefulWidget {
  const _EditAboutDialog({required this.currentBio});

  final String currentBio;

  @override
  State<_EditAboutDialog> createState() => _EditAboutDialogState();
}

class _EditAboutDialogState extends State<_EditAboutDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentBio);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About me'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 5,
        maxLength: 200,
        decoration: const InputDecoration(
          hintText: 'Fill in your personal signature',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
