import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/services/upload_service.dart';

const _attributes = ['Personal', 'Company', 'Entertainment', 'Gaming', 'Other'];

class AgencyInformationScreen extends ConsumerStatefulWidget {
  const AgencyInformationScreen({
    super.key,
    required this.agencyId,
    required this.canEdit,
    required this.initialName,
    required this.initialAnnouncement,
    this.initialLogoUrl,
    this.initialAttribute = 'Personal',
    this.initialWhatsapp = '',
    this.initialEmail = '',
  });

  final String agencyId;
  final bool canEdit;
  final String initialName;
  final String initialAnnouncement;
  final String? initialLogoUrl;
  final String initialAttribute;
  final String initialWhatsapp;
  final String initialEmail;

  @override
  ConsumerState<AgencyInformationScreen> createState() =>
      _AgencyInformationScreenState();
}

class _AgencyInformationScreenState
    extends ConsumerState<AgencyInformationScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _announceCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _emailCtrl;
  late String _attribute;
  String? _logoUrl;
  bool _clearLogo = false;
  bool _saving = false;
  bool _uploadingLogo = false;

  static const _fieldFill = Color(0xFFF2F2F4);
  static const _labelColor = Color(0xFF5A5A5A);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _announceCtrl = TextEditingController(text: widget.initialAnnouncement);
    _whatsappCtrl = TextEditingController(text: widget.initialWhatsapp);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _attribute = _attributes.contains(widget.initialAttribute)
        ? widget.initialAttribute
        : 'Personal';
    _logoUrl = widget.initialLogoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _announceCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (!widget.canEdit || _uploadingLogo) return;
    setState(() => _uploadingLogo = true);
    final url = await UploadService.instance.pickAndUploadAgencyLogo(context);
    if (!mounted) return;
    setState(() {
      _uploadingLogo = false;
      if (url != null) {
        _logoUrl = url;
        _clearLogo = false;
      }
    });
  }

  void _removeLogo() {
    if (!widget.canEdit) return;
    setState(() {
      _logoUrl = null;
      _clearLogo = true;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency Nickname is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(agencyCenterActionsProvider)
          .updateAgencyInfo(
            agencyId: widget.agencyId,
            name: name,
            announcement: _announceCtrl.text.trim(),
            attribute: _attribute,
            whatsapp: _whatsappCtrl.text.trim().isEmpty
                ? null
                : _whatsappCtrl.text.trim(),
            contactEmail: _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            logoUrl: _logoUrl,
            clearLogo: _clearLogo,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Agency info saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Agency Info',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(child: _logoPicker()),
          const SizedBox(height: 28),
          _label('Agency Nickname'),
          const SizedBox(height: 8),
          _field(controller: _nameCtrl, hint: 'Enter agency nickname'),
          const SizedBox(height: 18),
          _label('Agency Announcement'),
          const SizedBox(height: 8),
          _field(
            controller: _announceCtrl,
            hint: 'Write announcement…',
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          _label('Agency Attributes'),
          const SizedBox(height: 8),
          _attributeDropdown(),
          const SizedBox(height: 18),
          _label('Contact Information(WhatsApp)'),
          const SizedBox(height: 8),
          _field(
            controller: _whatsappCtrl,
            hint: 'WhatsApp number',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 18),
          _label('Contact Information(Email)'),
          const SizedBox(height: 8),
          _field(
            controller: _emailCtrl,
            hint: 'Email address',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 36),
          if (widget.canEdit) _sureButton(),
        ],
      ),
    );
  }

  Widget _logoPicker() {
    final hasLogo = _logoUrl != null && _logoUrl!.isNotEmpty;
    return GestureDetector(
      onTap: widget.canEdit ? _pickLogo : null,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _fieldFill,
                border: Border.all(color: const Color(0xFFE8E8EC)),
                image: hasLogo
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(_logoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _uploadingLogo
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasLogo
                  ? null
                  : const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: Color(0xFF9A9AA3),
                    ),
            ),
            if (widget.canEdit && hasLogo)
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: _removeLogo,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A4A52),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else if (widget.canEdit)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A4A52),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _labelColor,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: widget.canEdit,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0B0B8), fontSize: 14),
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B8CFF), width: 1.2),
        ),
      ),
    );
  }

  Widget _attributeDropdown() {
    return AbsorbPointer(
      absorbing: !widget.canEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _attribute,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF8A8A92),
            ),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            items: _attributes
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _attribute = v);
            },
          ),
        ),
      ),
    );
  }

  Widget _sureButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF4C8DFF), Color(0xFF7B6CFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C8DFF).withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _saving ? null : _save,
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sure',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
