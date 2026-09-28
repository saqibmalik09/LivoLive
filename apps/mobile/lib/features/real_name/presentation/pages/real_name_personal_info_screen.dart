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

class RealNamePersonalInfoScreen extends ConsumerStatefulWidget {
  const RealNamePersonalInfoScreen({super.key});

  @override
  ConsumerState<RealNamePersonalInfoScreen> createState() =>
      _RealNamePersonalInfoScreenState();
}

class _RealNamePersonalInfoScreenState
    extends ConsumerState<RealNamePersonalInfoScreen> {
  final _country = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _age = TextEditingController();
  final _howKnow = TextEditingController();
  String? _yearsOfWork;
  String? _external;
  String? _workAccount;
  String? _results;
  bool _loading = false;
  bool _uploading = false;
  bool _seeded = false;

  static const _yearOptions = [
    'Less than 1 year',
    '1-2 years',
    '2-3 years',
    '3-5 years',
    '5+ years',
  ];

  @override
  void dispose() {
    _country.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _age.dispose();
    _howKnow.dispose();
    super.dispose();
  }

  void _seed(RealNameCenterState state) {
    if (_seeded) return;
    _seeded = true;
    final a = state.application;
    _country.text = a.country ?? '';
    _phone.text = a.telephone ?? state.phone ?? '';
    _whatsapp.text = a.whatsapp ?? '';
    _age.text = a.age?.toString() ?? '';
    _howKnow.text = a.howKnowApp ?? '';
    _yearsOfWork = a.yearsOfWork;
    _external = a.proofExternalAppUrl;
    _workAccount = a.proofWorkAccountUrl;
    _results = a.proofWorkResultsUrl;
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
    final age = int.tryParse(_age.text.trim());
    if (_country.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        age == null ||
        _yearsOfWork == null ||
        _howKnow.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    if (_external == null || _workAccount == null || _results == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all 3 required pictures')),
      );
      return;
    }

    setState(() => _loading = true);
    final personal = await RealNameActions.upsertStep(
      step: 'step1_personal',
      payload: {
        'country': _country.text.trim(),
        'telephone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'age': age,
        'years_of_work': _yearsOfWork,
        'how_know_app': _howKnow.text.trim(),
      },
    );
    if (personal['success'] != true) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(personal['message']?.toString() ?? 'Failed')),
      );
      return;
    }

    final proofs = await RealNameActions.upsertStep(
      step: 'step1_proofs',
      payload: {
        'proof_external_app_url': _external,
        'proof_work_account_url': _workAccount,
        'proof_work_results_url': _results,
      },
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (proofs['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(proofs['message']?.toString() ?? 'Failed')),
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
        appBar: AppBar(title: const Text('Personal information')),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => asyncErrorWidget(e),
          data: (state) {
            if (state == null) return const SizedBox.shrink();
            _seed(state);
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
                            'Please enter real information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: RealNameTheme.text,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RealNameLabeledField(
                            label: 'ID',
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RealNameTheme.border),
                              ),
                              child: Text(
                                state.shortId,
                                style: const TextStyle(
                                  color: RealNameTheme.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: 'Country',
                            required: true,
                            child: TextField(
                              controller: _country,
                              decoration: const InputDecoration(
                                hintText: 'Country',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: context.l10n.realName_telephone,
                            required: true,
                            child: TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: context.l10n.realName_telephone,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: context.l10n.realName_whatsapp,
                            child: TextField(
                              controller: _whatsapp,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: 'WhatsApp number',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: 'Age',
                            required: true,
                            child: TextField(
                              controller: _age,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Please fill in your age',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: 'Years of work',
                            required: true,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                hintText: 'Select years of work',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _yearsOfWork,
                                  isExpanded: true,
                                  hint: const Text('Select years of work'),
                                  items: _yearOptions
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _yearsOfWork = v),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RealNameLabeledField(
                            label: 'How did you know about our app',
                            required: true,
                            child: TextField(
                              controller: _howKnow,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText:
                                    'Please fill in your how to know our application',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ProofUploadTile(
                            label: 'Screenshot proof from which external APP',
                            url: _external,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) setState(() => _external = url);
                            },
                          ),
                          const SizedBox(height: 16),
                          _ProofUploadTile(
                            label: context.l10n.realName_workProofScreenshot,
                            url: _workAccount,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) {
                                setState(() => _workAccount = url);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _ProofUploadTile(
                            label: 'Work data and results',
                            url: _results,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) setState(() => _results = url);
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

class _ProofUploadTile extends StatelessWidget {
  const _ProofUploadTile({
    required this.label,
    required this.url,
    required this.onTap,
  });

  final String label;
  final String? url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RealNameLabeledField(
      label: label,
      required: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RealNameTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null
              ? KycPreviewImage(pathOrUrl: url!)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: RealNameTheme.textMuted,
                      size: 28,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'upload picture',
                      style: TextStyle(
                        color: RealNameTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
