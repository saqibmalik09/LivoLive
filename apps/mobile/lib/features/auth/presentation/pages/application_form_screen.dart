import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApplicationFormScreen extends ConsumerStatefulWidget {
  final String type;
  const ApplicationFormScreen({super.key, required this.type});

  @override
  ConsumerState<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _agencyCodeController = TextEditingController();
  final _staffCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _agencyCodeController.dispose();
    _staffCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (widget.type == 'host') {
        final res = await supabase.rpc(
          'submit_host_agency_application',
          params: {'p_agency_ref': _agencyCodeController.text.trim()},
        );
        final map = Map<String, dynamic>.from(res as Map);
        if (map['success'] != true) {
          throw map['message']?.toString() ??
              'Invalid Agency Code / Owner ID. Check with your Agency Owner.';
        }
      } else {
        final staffCode = _staffCodeController.text.trim();
        if (staffCode.isEmpty) {
          throw 'Enter a valid BD ID';
        }

        final res = await supabase.rpc(
          'submit_agency_application',
          params: {
            'p_real_name': _nameController.text.trim(),
            'p_whatsapp': _whatsappController.text.trim(),
            'p_bd_staff_code': staffCode,
          },
        );
        final map = Map<String, dynamic>.from(res as Map);
        if (map['success'] != true) {
          throw map['message']?.toString() ?? 'Enter a valid BD ID';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('duplicate')
                  ? 'You have already applied!'
                  : e.toString(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final title = widget.type == 'host'
        ? context.l10n.app_hostApplication
        : 'Agency Application';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(title),
              const SizedBox(height: 32),

              _buildReadOnlyField(
                'User ID',
                user?['short_id']?.toString() ??
                    user?['id']?.toString().substring(0, 8).toUpperCase() ??
                    '',
              ),
              const SizedBox(height: 16),
              _buildReadOnlyField('Username', user?['username'] ?? ''),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              _buildInputField(
                label: context.l10n.app_realName,
                hint: 'Enter your full name',
                icon: Iconsax.user,
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 20),
              _buildInputField(
                label: context.l10n.app_whatsappNumber,
                hint: 'e.g. +92 300 1234567',
                icon: Iconsax.call,
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.isEmpty
                    ? 'Please enter WhatsApp number'
                    : null,
              ),
              if (widget.type == 'host') ...[
                const SizedBox(height: 20),
                _buildInputField(
                  label: 'Agency Code / Owner ID',
                  hint: '6-digit agency code or owner short ID',
                  icon: Iconsax.hierarchy,
                  controller: _agencyCodeController,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter agency code or owner ID';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(val.trim())) {
                      return 'Digits only';
                    }
                    return null;
                  },
                ),
              ],
              if (widget.type == 'agency') ...[
                const SizedBox(height: 20),
                _buildInputField(
                  label: 'BD ID',
                  hint: 'BD staff code or BD short ID',
                  icon: Iconsax.code,
                  controller: _staffCodeController,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'BD ID is required';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(val.trim())) {
                      return 'Digits only';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Application',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          widget.type == 'host' ? Iconsax.microphone : Iconsax.hierarchy,
          size: 50,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Apply as a ${widget.type.capitalize()}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Fill in your details below to join our community.',
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() => "${this[0].toUpperCase()}${substring(1)}";
}
