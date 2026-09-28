import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/real_name/data/real_name_provider.dart';
import 'package:sk_live/features/real_name/presentation/widgets/kyc_preview_image.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_common.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_theme.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class RealNameIdentityScreen extends ConsumerStatefulWidget {
  const RealNameIdentityScreen({super.key});

  @override
  ConsumerState<RealNameIdentityScreen> createState() =>
      _RealNameIdentityScreenState();
}

class _RealNameIdentityScreenState
    extends ConsumerState<RealNameIdentityScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _doc = TextEditingController();
  String? _front;
  String? _back;
  bool _loading = false;
  bool _uploading = false;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _doc.dispose();
    super.dispose();
  }

  void _seed(RealNameApplication app) {
    if (_seeded) return;
    _seeded = true;
    _name.text = app.legalName ?? '';
    _address.text = app.residentialAddress ?? '';
    _doc.text = app.documentNumber ?? '';
    _front = app.idPhotoFrontUrl;
    _back = app.idPhotoBackUrl;
  }

  Future<String?> _pickUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      return await RealNameActions.uploadKycFile(
        bytes: Uint8List.fromList(bytes),
        fileName: file.name,
        contentType: 'image/jpeg',
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _doc.text.trim().isEmpty ||
        _front == null ||
        _back == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }
    setState(() => _loading = true);
    final res = await RealNameActions.upsertStep(
      step: 'step2_identity',
      payload: {
        'legal_name': _name.text.trim(),
        'residential_address': _address.text.trim(),
        'document_number': _doc.text.trim(),
        'id_photo_front_url': _front,
        'id_photo_back_url': _back,
      },
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Failed')),
      );
      return;
    }
    ref.invalidate(realNameCenterProvider);
    await RealNameActions.submitForReview();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(realNameCenterProvider);

    return Theme(
      data: RealNameTheme.light(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Identity information authentication'),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => asyncErrorWidget(e),
          data: (state) {
            if (state != null) _seed(state.application);
            return Stack(
              children: [
                Column(
                  children: [
                    const RealNameWarningBanner(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          const Text(
                            'Use valid ID information for authentication',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: RealNameTheme.text,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RealNameLabeledField(
                            label: 'Real Name',
                            required: true,
                            child: TextField(
                              controller: _name,
                              decoration: const InputDecoration(
                                hintText: 'Please fill in your real name',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: 'Residential Address',
                            required: true,
                            child: TextField(
                              controller: _address,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Please fill in your home address',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: 'Document Number',
                            required: true,
                            child: TextField(
                              controller: _doc,
                              decoration: const InputDecoration(
                                hintText: 'Please fill in your card number',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const RealNameLabeledField(
                            label: 'Upload ID photo',
                            required: true,
                            child: Text(
                              'Please ensure that the border of the document is complete, the font is clear, and the brightness is even',
                              style: TextStyle(
                                color: RealNameTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _IdUploadBox(
                            label: 'Click to upload ID card face',
                            url: _front,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) setState(() => _front = url);
                            },
                          ),
                          const SizedBox(height: 12),
                          _IdUploadBox(
                            label: 'Click to upload ID card back',
                            url: _back,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) setState(() => _back = url);
                            },
                          ),
                          const SizedBox(height: 24),
                          RealNamePrimaryButton(
                            label: context.l10n.common_submit,
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_uploading)
                  Container(
                    color: Colors.black38,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Loading...'),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IdUploadBox extends StatelessWidget {
  const _IdUploadBox({
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: RealNameTheme.primary.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null
            ? KycPreviewImage(pathOrUrl: url!)
            : Center(
                child: Text(
                  label,
                  style: const TextStyle(color: RealNameTheme.textMuted),
                ),
              ),
      ),
    );
  }
}
