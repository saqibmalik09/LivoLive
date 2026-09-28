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

class RealNameWorkProofScreen extends ConsumerStatefulWidget {
  const RealNameWorkProofScreen({super.key});

  @override
  ConsumerState<RealNameWorkProofScreen> createState() =>
      _RealNameWorkProofScreenState();
}

class _RealNameWorkProofScreenState
    extends ConsumerState<RealNameWorkProofScreen> {
  String? _external;
  String? _workAccount;
  String? _results;
  bool _loading = false;
  bool _uploading = false;
  bool _seeded = false;

  void _seed(RealNameApplication app) {
    if (_seeded) return;
    _seeded = true;
    _external = app.proofExternalAppUrl;
    _workAccount = app.proofWorkAccountUrl;
    _results = app.proofWorkResultsUrl;
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
      final url = await RealNameActions.uploadKycFile(
        bytes: Uint8List.fromList(bytes),
        fileName: file.name,
        contentType: 'image/jpeg',
      );
      return url;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_external == null || _workAccount == null || _results == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required pictures')),
      );
      return;
    }
    setState(() => _loading = true);
    final res = await RealNameActions.upsertStep(
      step: 'step1_proofs',
      payload: {
        'proof_external_app_url': _external,
        'proof_work_account_url': _workAccount,
        'proof_work_results_url': _results,
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
                          _UploadBlock(
                            label: 'Screenshot proof from which external APP',
                            url: _external,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) setState(() => _external = url);
                            },
                          ),
                          const SizedBox(height: 16),
                          _UploadBlock(
                            label: context.l10n.realName_workProofScreenshot,
                            url: _workAccount,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null)
                                setState(() => _workAccount = url);
                            },
                          ),
                          const SizedBox(height: 16),
                          _UploadBlock(
                            label: 'Work data and results',
                            url: _results,
                            onTap: () async {
                              final url = await _pickUpload();
                              if (url != null) setState(() => _results = url);
                            },
                          ),
                          const SizedBox(height: 28),
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

class _UploadBlock extends StatelessWidget {
  const _UploadBlock({
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
