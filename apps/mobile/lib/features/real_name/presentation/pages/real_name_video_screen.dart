import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:sk_live/features/real_name/data/real_name_provider.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_common.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_theme.dart';

class RealNameVideoScreen extends ConsumerStatefulWidget {
  const RealNameVideoScreen({super.key});

  @override
  ConsumerState<RealNameVideoScreen> createState() =>
      _RealNameVideoScreenState();
}

class _RealNameVideoScreenState extends ConsumerState<RealNameVideoScreen> {
  String? _videoUrl;
  bool _loading = false;
  bool _uploading = false;
  VideoPlayerController? _preview;

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _recordOrPick() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 8),
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await RealNameActions.uploadKycFile(
        bytes: Uint8List.fromList(bytes),
        fileName: 'video_auth.mp4',
        contentType: 'video/mp4',
      );
      if (url == null) throw 'Upload failed';
      _preview?.dispose();
      _preview = VideoPlayerController.networkUrl(Uri.parse(url));
      await _preview!.initialize();
      setState(() => _videoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record your video first')),
      );
      return;
    }
    setState(() => _loading = true);
    final res = await RealNameActions.upsertStep(
      step: 'step3_video',
      payload: {'video_auth_url': _videoUrl},
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
    return Theme(
      data: RealNameTheme.light(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('Video Authentication')),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Text(
                  'Use a mobile device to record a 5-s video. Upper body visible and holding the front side of the ID card.',
                  style: TextStyle(
                    color: RealNameTheme.text,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: RealNameTheme.primary.withValues(alpha: 0.4),
                    ),
                    color: const Color(0xFFF0F7FF),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 48,
                          color: RealNameTheme.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Example: hold ID card in front of chest',
                          style: TextStyle(
                            color: RealNameTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RealNameTheme.border),
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _preview != null && _preview!.value.isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _preview!.value.aspectRatio,
                              child: VideoPlayer(_preview!),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_preview!.value.isPlaying) {
                                    _preview!.pause();
                                  } else {
                                    _preview!.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _preview!.value.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: _recordOrPick,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: RealNameTheme.primary,
                                child: Icon(
                                  Icons.videocam,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Start Recording',
                                style: TextStyle(
                                  color: RealNameTheme.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (_videoUrl != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _recordOrPick,
                    child: const Text('Re-record'),
                  ),
                ],
                const SizedBox(height: 24),
                RealNamePrimaryButton(
                  label: 'Submit',
                  loading: _loading,
                  onPressed: _submit,
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
        ),
      ),
    );
  }
}
