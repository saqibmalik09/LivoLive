import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/services/upload_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key});

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String? _selectedImageUrl;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final response = await Supabase.instance.client
          .from('support_messages')
          .select()
          .eq('user_id', user!.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(response);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isUploadingImage = true);
    try {
      final url = await UploadService.instance.pickSupportScreenshot(context);
      if (url != null) {
        setState(() => _selectedImageUrl = url);
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('support_messages').insert({
        'user_id': user!.id,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'image_url': _selectedImageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.contact_messageSent),
            backgroundColor: Colors.green,
          ),
        );
        _subjectController.clear();
        _messageController.clear();
        setState(() => _selectedImageUrl = null);
        _fetchHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sending message'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.contact_title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageForm(),
            const SizedBox(height: 40),
            Text(
              l10n.contact_previousTickets,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageForm() {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            label: l10n.contact_subject,
            hint: l10n.contact_enterSubject,
            controller: _subjectController,
            icon: Iconsax.info_circle,
            validator: (v) => v!.isEmpty ? l10n.contact_enterSubject : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: l10n.contact_message,
            hint: l10n.contact_enterMessage,
            controller: _messageController,
            icon: Iconsax.message_text,
            maxLines: 5,
            validator: (v) => v!.isEmpty ? l10n.contact_enterMessage : null,
          ),
          const SizedBox(height: 20),
          _buildImagePicker(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      l10n.contact_sendMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.contact_attachmentOptional,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10),
            ),
            child: _selectedImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        Image.network(
                          _selectedImageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedImageUrl = null),
                            child: const CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 12,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: _isUploadingImage
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Iconsax.image,
                                color: Colors.white24,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.l10n.contact_tapUploadScreenshot,
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    final l10n = context.l10n;
    if (_isLoadingHistory)
      return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty)
      return Text(
        l10n.contact_noHistory,
        style: const TextStyle(color: Colors.white24),
      );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final msg = _history[index];
        final isReplied = msg['status'] == 'replied';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isReplied
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      msg['subject'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isReplied
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isReplied ? l10n.contact_replied : l10n.contact_pending,
                      style: TextStyle(
                        color: isReplied
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                msg['message'],
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              if (msg['image_url'] != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: msg['image_url'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
              ],
              if (isReplied && msg['admin_reply'] != null) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Iconsax.verify,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.contact_adminReply,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  msg['admin_reply'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                msg['created_at'].toString().substring(0, 16),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.05),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
