import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/family_provider.dart';
import 'package:sk_live/core/providers/profile_provider.dart';
import 'package:sk_live/features/home/presentation/pages/family_management_screen.dart';

class CreateFamilyScreen extends ConsumerStatefulWidget {
  final FamilyModel? existingFamily;

  const CreateFamilyScreen({super.key, this.existingFamily});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  String? _selectedImagePath;
  bool _approvalRequired = true;
  bool _isLoading = false;

  bool get _isUpdateMode => widget.existingFamily != null;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (_isUpdateMode) {
      _nameController.text = widget.existingFamily!.name;
      _tagController.text = widget.existingFamily!.tag ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImagePath = image.path);
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.family_enterName)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isUpdateMode) {
        await FamilyActions.updateFamily(
          familyId: widget.existingFamily!.id,
          name: _nameController.text.trim(),
          tag: _tagController.text.trim(),
          localImagePath: _selectedImagePath,
          approvalRequired: _approvalRequired,
        );
        if (mounted) {
          ref.invalidate(userFamilyProvider);
          ref.invalidate(topFamiliesProvider);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Family updated successfully!')),
          );
        }
      } else {
        await FamilyActions.createFamily(
          name: _nameController.text.trim(),
          tag: _tagController.text.trim(),
          approvalRequired: _approvalRequired,
          localImagePath: _selectedImagePath,
        );
        if (mounted) {
          ref.invalidate(topFamiliesProvider);
          ref.invalidate(userFamilyProvider);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Family created successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final costAsync = ref.watch(familyCreationCostProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF3EEFF), Color(0xFFE8D8FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Color(0xFF5A35D1),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        _isUpdateMode
                            ? 'Edit Family'
                            : context.l10n.family_createTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF2D1B6B),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildFormContent(costAsync),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent(AsyncValue<int> costAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Column(
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF7B61FF),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                    image: _selectedImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_selectedImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : (widget.existingFamily?.avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                    widget.existingFamily!.avatarUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null),
                  ),
                  child:
                      (_selectedImagePath == null &&
                          widget.existingFamily?.avatarUrl == null)
                      ? const Icon(
                          Icons.add,
                          color: Color(0xFF7B61FF),
                          size: 50,
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  _isUpdateMode ? 'Tap to change logo' : 'Upload family logo',
                  style: const TextStyle(
                    color: Color(0xFF5A35D1),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),

        _buildLabel('Family name'),
        _buildTextField(_nameController, 'Enter family name', 20),
        _buildSubLabel('Choose a unique name that represents your family'),
        const SizedBox(height: 20),

        _buildLabel('Family tag'),
        _buildTextField(_tagController, 'Enter short tag (max 10)', 10),
        _buildSubLabel('A short identifier shown next to your family name'),
        const SizedBox(height: 30),

        _buildSectionTitle('Preview'),
        const SizedBox(height: 15),
        _buildPreviewCard(),
        const SizedBox(height: 30),

        _buildSectionTitle('Application settings'),
        const SizedBox(height: 10),
        _buildRadioOption('Approval required to join the family', true),
        _buildRadioOption(
          'No approval required, join the family directly',
          false,
        ),
        const SizedBox(height: 40),

        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _isLoading ? null : _submit,
                child: _buildMainButton(),
              ),
              if (!_isUpdateMode) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF7B61FF),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      costAsync.when(
                        data: (cost) => cost.toString(),
                        loading: () => '...',
                        error: (_, _) => '200000',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF5A35D1),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (_isUpdateMode) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FamilyManagementScreen(familyId: widget.existingFamily!.id),
              ),
            ),
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF5A45D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.manage_accounts, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Family Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),
        if (!_isUpdateMode)
          const Text(
            '*After creating a family, if you do not log in for 15 days, the position of family leader will automatically transfer',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9E8EC5), fontSize: 11),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF2D1B6B),
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF2D1B6B),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildSubLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF9E8EC5), fontSize: 11),
    ),
  );

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    int maxLength,
  ) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      style: const TextStyle(
        color: Color(0xFF2D1B6B),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB8A8E0), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8CBFF), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 2),
        ),
        counterStyle: const TextStyle(color: Color(0xFFB8A8E0), fontSize: 11),
      ),
    );
  }

  Widget _buildRadioOption(String text, bool value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Radio<bool>(
        value: value,
        groupValue: _approvalRequired,
        activeColor: const Color(0xFF7B61FF),
        onChanged: (val) {
          if (val != null) setState(() => _approvalRequired = val);
        },
      ),
      title: Text(
        text,
        style: const TextStyle(color: Color(0xFF4A3A7A), fontSize: 14),
      ),
      onTap: () => setState(() => _approvalRequired = value),
    );
  }

  Widget _buildPreviewCard() {
    final hasImage =
        _selectedImagePath != null || widget.existingFamily?.avatarUrl != null;
    final hasName = _nameController.text.isNotEmpty;
    final hasTag = _tagController.text.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B6B), Color(0xFF4A2FA0), Color(0xFF1A0A40)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7B61FF).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B61FF).withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: hasImage
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF7B61FF), Color(0xFF5A35D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                image: _selectedImagePath != null
                    ? DecorationImage(
                        image: FileImage(File(_selectedImagePath!)),
                        fit: BoxFit.cover,
                      )
                    : (widget.existingFamily?.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(
                                widget.existingFamily!.avatarUrl!,
                              ),
                              fit: BoxFit.cover,
                            )
                          : null),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: !hasImage
                  ? const Icon(
                      Icons.groups_rounded,
                      color: Colors.white70,
                      size: 36,
                    )
                  : null,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? _nameController.text : 'Family Name',
                    style: TextStyle(
                      color: hasName ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  if (hasTag)
                    SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: ClipPath(
                              clipper: TagRibbonClipper(),
                              child: Container(
                                height: 15,
                                constraints: const BoxConstraints(
                                  maxWidth: 100,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  0,
                                  12,
                                  0,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00E5FF),
                                      Color(0xFF00B0CC),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    _tagController.text.length > 6
                                        ? '${_tagController.text.substring(0, 6)}...'
                                        : _tagController.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final currentLevel =
                                  widget.existingFamily?.level ?? 0;
                              final badgeAsync = ref.watch(
                                familyBadgeProvider(currentLevel),
                              );
                              return badgeAsync.when(
                                data: (url) => url != null
                                    ? CachedNetworkImage(
                                        imageUrl: url,
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.shield,
                                        color: Color(0xFFFFD700),
                                        size: 22,
                                      ),
                                loading: () =>
                                    const SizedBox(width: 24, height: 24),
                                error: (_, _) => const Icon(
                                  Icons.shield,
                                  color: Color(0xFFFFD700),
                                  size: 22,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Tag Preview',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Lv.1  •  0 members',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return Container(
      width: 240,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF5A35D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B61FF).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              )
            : Text(
                _isUpdateMode
                    ? 'Save Changes'
                    : context.l10n.family_createTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class TagRibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double radius = 6;
    double pointWidth = 10;

    path.moveTo(radius, 0);
    path.lineTo(size.width - pointWidth - radius, 0);
    path.quadraticBezierTo(
      size.width - pointWidth,
      0,
      size.width - (pointWidth / 2),
      size.height / 4,
    );

    path.lineTo(size.width, size.height / 2);

    path.lineTo(size.width - (pointWidth / 2), size.height * 0.75);
    path.quadraticBezierTo(
      size.width - pointWidth,
      size.height,
      size.width - pointWidth - radius,
      size.height,
    );

    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);

    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
